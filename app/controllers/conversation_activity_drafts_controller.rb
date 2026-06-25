# PB-020 (Triagem) — atividades de 2º nível (rascunhos manuais) de uma conversa.
# Aninhado em /conversations/:conversation_id/activity_drafts. Itens SEMPRE escopados
# pela conversa da URL (impede manipular item de outra conversa cruzando IDs).
# Volta sempre ao detalhe em modo triagem. NÃO cria Task/TimeEntry, NÃO toca
# ConversationLink, NÃO chama IA.
class ConversationActivityDraftsController < ApplicationController
  before_action :set_conversation
  before_action :set_draft, only: %i[update destroy]

  def create
    @draft = @conversation.activity_drafts.new(create_params)
    @draft.created_by = current_user
    @draft.updated_by = current_user
    @draft.position ||= next_position
    authorize @draft
    if @draft.save
      redirect_to triage_target, notice: "Atividade adicionada."
    else
      redirect_to triage_target, alert: error_message(@draft, "Não foi possível adicionar a atividade.")
    end
  end

  def update
    @draft.assign_attributes(update_params)
    @draft.updated_by = current_user
    if @draft.save
      redirect_to triage_target, notice: "Atividade atualizada."
    else
      redirect_to triage_target, alert: error_message(@draft, "Não foi possível atualizar a atividade.")
    end
  end

  def destroy
    @draft.destroy
    redirect_to triage_target, notice: "Atividade removida."
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  # Escopado pela conversa da URL: item de outra conversa → 404 (não vaza).
  def set_draft
    @draft = @conversation.activity_drafts.find(params[:id])
    authorize @draft
  end

  # Criação: título/descrição manuais (status/source/position têm default seguro).
  def create_params
    params.require(:activity_draft).permit(:title, :description)
  end

  # Atualização: título/descrição e mudança de status pela lista permitida.
  # `status` inválido é descartado (não estoura, não grava valor livre).
  def update_params
    permitted = params.require(:activity_draft).permit(:title, :description, :status)
    permitted.delete(:status) unless ConversationActivityDraft::STATUSES.include?(permitted[:status])
    permitted
  end

  def next_position
    (@conversation.activity_drafts.maximum(:position) || -1) + 1
  end

  def triage_target
    conversation_path(@conversation, mode: "triage", anchor: "atividades")
  end

  def error_message(draft, fallback)
    draft.errors.full_messages.to_sentence.presence || fallback
  end
end
