class Api::V1::Accounts::Conversations::BotResumesController < Api::V1::Accounts::BaseController
  def create
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize conversation, :show?
    raise Pundit::NotAuthorizedError unless Current.user.is_a?(User) && Current.user.id != 7
    request_id = params[:request_id].to_s
    unless request_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      return render json: { error: 'Solicitação inválida. Atualize a página e tente novamente.' }, status: :unprocessable_entity
    end
    result = Cbn::LeadBotResumeService.new(conversation: conversation, actor: Current.user, request_id: request_id).perform
    render json: result
  rescue Cbn::LeadBotResumeService::Unavailable => error
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
