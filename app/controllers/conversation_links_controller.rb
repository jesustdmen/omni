class ConversationLinksController < ApplicationController
  # F4 — vínculo manual conversa↔tarefa (aninhado em conversations/:conversation_id/links).
  before_action :set_conversation

  def create
    @link = @conversation.conversation_links.new(
      task_id: params[:task_id],
      link_type: link_type_param,
      origin: "manual",
      created_by: current_user
    )
    authorize @link

    if @link.save
      redirect_to @conversation, notice: "Conversa vinculada à tarefa."
    else
      redirect_to @conversation, alert: @link.errors.full_messages.to_sentence.presence || "Não foi possível vincular."
    end
  end

  def destroy
    @link = @conversation.conversation_links.find(params[:id])
    authorize @link
    @link.destroy
    redirect_to @conversation, notice: "Vínculo removido."
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  # origin é sempre "manual" nesta fatia; link_type vem do form (default primary).
  def link_type_param
    ConversationLink::LINK_TYPES.include?(params[:link_type]) ? params[:link_type] : "primary"
  end
end
