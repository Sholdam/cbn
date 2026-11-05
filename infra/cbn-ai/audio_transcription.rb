require 'net/http'
require 'json'
require 'tempfile'
require 'open3'
require 'timeout'

module Cbn
  class AudioTranscription
    MODEL = 'gpt-transcribe'.freeze
    LIMIT = 25_000_000
    ENDPOINT = URI('https://api.openai.com/v1/audio/transcriptions').freeze
    class Failure < StandardError; end

    def self.credential(account_id)
      hook = Integrations::Hook.where(account_id: account_id, app_id: 'openai', status: :enabled).order(:id).last
      key = hook&.settings&.[]('api_key')
      raise Failure, 'Conecte uma chave OpenAI válida nas integrações do CRM.' unless key.is_a?(String) && key.start_with?('sk-')
      key
    end

    def self.validate!(attachment)
      raise Failure, 'Este anexo não é um áudio disponível.' unless attachment.account_id == 1 && attachment.audio? && attachment.file.attached?
      raise Failure, 'Este áudio excede o limite de 25 MB para transcrição.' if attachment.file.blob.byte_size > LIMIT
      raise Failure, 'Esta mensagem foi excluída.' if attachment.message.content_attributes&.[]('deleted')
    end

    def initialize(attachment)
      @attachment = attachment
    end

    def perform
      self.class.validate!(@attachment)
      key = self.class.credential(@attachment.account_id)
      # Stored blobs only: caller-supplied URLs never reach FFmpeg or OpenAI.
      @attachment.file.blob.open do |source|
        Tempfile.create(['cbn-transcription-', '.webm']) do |converted|
          convert(source.path, converted.path)
          raise Failure, 'O áudio convertido excede o limite de 25 MB.' if File.size(converted.path) > LIMIT
          request(converted.path, key)
        end
      end
    end

    private

    def convert(source, destination)
      status = nil
      Open3.popen3('ffmpeg', '-nostdin', '-y', '-v', 'error', '-protocol_whitelist', 'file,pipe', '-i', source,
                   '-map', '0:a:0', '-vn', '-ac', '1', '-c:a', 'libopus', '-b:a', '32k', '-fs', (LIMIT + 1).to_s, destination) do |input, output, errors, process|
        input.close
        output.close
        reader = Thread.new { errors.read }
        begin
          Timeout.timeout(120) { status = process.value }
        rescue Timeout::Error
          Process.kill('KILL', process.pid) rescue nil
          raise Failure, 'O áudio demorou demais para processar. Tente um arquivo menor.'
        ensure
          reader.join(2)
        end
      end
      raise Failure, 'Não foi possível ler este áudio.' unless status&.success? && File.size?(destination)
    end

    def request(path, key)
      File.open(path, 'rb') do |file|
        req = Net::HTTP::Post.new(ENDPOINT)
        req['Authorization'] = 'Bearer ' + key
        req.set_form([['model', MODEL], ['languages[]', 'pt'], ['file', file, { filename: 'audio.webm', content_type: 'audio/webm' }]], 'multipart/form-data')
        http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 120
        http.write_timeout = 30
        response = http.request(req)
        unless response.code == '200'
          message = case response.code
                    when '401', '403' then 'A chave conectada não tem acesso à transcrição. Confira a integração OpenAI.'
                    when '404' then 'O modelo gpt-transcribe não está disponível para a chave conectada.'
                    when '429' then 'A OpenAI informou limite de uso ou saldo insuficiente. Confira sua conta.'
                    else 'A OpenAI não concluiu a transcrição. Tente novamente mais tarde.'
                    end
          raise Failure, message
        end
        data = JSON.parse(response.body)
        text = data['text']
        raise Failure, 'Nenhuma fala foi reconhecida neste áudio.' unless text.is_a?(String) && !text.strip.empty? && text.length <= 200_000
        text.strip
      end
    rescue JSON::ParserError
      raise Failure, 'A resposta da transcrição não pôde ser lida.'
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, IOError, SystemCallError
      raise Failure, 'Não foi possível confirmar a transcrição. Tente novamente mais tarde.'
    end
  end
end
