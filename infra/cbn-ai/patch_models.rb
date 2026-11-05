require 'yaml'
require 'json'
root = ARGV.fetch(0)
path = File.join(root, 'config/llm.yml')
config = YAML.load_file(path)
config.fetch('models')['gpt-6-luna'] = { 'provider' => 'openai', 'display_name' => 'GPT-6 Luna', 'credit_multiplier' => 1 }
config.fetch('models')['gpt-transcribe'] = { 'provider' => 'openai', 'display_name' => 'GPT Transcribe', 'credit_multiplier' => 1 }
config.fetch('features').fetch('editor').fetch('models').push('gpt-6-luna').uniq!
config.fetch('features').fetch('audio_transcription').fetch('models').push('gpt-transcribe').uniq!
File.write(path, YAML.dump(config))
registry_path = File.join(root, 'config/llm_models.json')
registry = JSON.parse(File.read(registry_path))
unless registry.any? { |model| model['id'] == 'gpt-6-luna' && model['provider'] == 'openai' }
  model = Marshal.load(Marshal.dump(registry.find { |item| item['id'] == 'gpt-4.1-mini' && item['provider'] == 'openai' } || raise('OpenAI registry template missing')))
  model.merge!('id' => 'gpt-6-luna', 'name' => 'GPT-6 Luna', 'context_window' => 1_050_000, 'max_output_tokens' => 128_000, 'knowledge_cutoff' => '2026-05-18')
  model['capabilities'] = ['function_calling', 'structured_output', 'vision', 'reasoning']
  model['pricing'] = { 'text_tokens' => { 'standard' => { 'input_per_million' => 0.10, 'output_per_million' => 0.50, 'cache_read_input_per_million' => 0.01 } } }
  registry << model
end
File.write(registry_path, JSON.pretty_generate(registry))
