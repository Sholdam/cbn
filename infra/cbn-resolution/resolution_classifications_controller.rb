class Api::V1::Accounts::Conversations::ResolutionClassificationsController < Api::V1::Accounts::Conversations::BaseController
  before_action :cbn_account!

  def show
    render json: context
  end

  def create
    choice = params[:classification]
    unless choice.is_a?(String) && CbnResolutionClassification.options(Current.account.id).include?(choice)
      return render json: { error: CbnResolutionClassification::ERROR }, status: :unprocessable_entity
    end
    unless params[:last_message_id].is_a?(Integer)
      return render json: { error: 'Abra novamente a seleção antes de resolver.' }, status: :unprocessable_entity
    end

    @conversation.with_lock do
      if @conversation.resolved?
        if @conversation.additional_attributes&.dig('cbn_resolution', 'classification') == choice
          return render json: { current_status: 'resolved', classification: choice, conversation_id: @conversation.display_id }
        end
        return render json: { error: 'A conversa já está resolvida. Reabra antes de alterar a classificação do encerramento.' }, status: :conflict
      end
      # A new customer/agent message must be reviewed instead of silently closed
      # using the stale dialog. Incoming after this transaction reopens natively.
      if last_message_id != params[:last_message_id]
        return render json: { error: 'Chegou uma nova mensagem. Confira a conversa antes de resolver.' }, status: :conflict
      end
      @conversation.contact.with_lock do
        @conversation.contact.update!(custom_attributes: (@conversation.contact.custom_attributes || {}).merge(CbnResolutionClassification::KEY => choice))
        @conversation.update!(status: :resolved)
      end
    end
    render json: { current_status: @conversation.status, classification: choice, conversation_id: @conversation.display_id }
  end

  private

  def cbn_account!
    head :not_found unless Current.account.id == 1
  end

  def last_message_id
    @conversation.messages.where(message_type: [0, 1]).maximum(:id) || 0
  end

  def context
    {
      options: CbnResolutionClassification.options(Current.account.id),
      classification: @conversation.contact.custom_attributes&.dig(CbnResolutionClassification::KEY),
      current_status: @conversation.status, last_message_id: last_message_id
    }
  end
end
