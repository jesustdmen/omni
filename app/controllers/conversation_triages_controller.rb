# PB-020 (Triagem persistida mínima) — persiste a decisão HUMANA de triagem (1:1).
# Ação única `update` (upsert da linha em conversation_triages). Read/derive continua
# no service ConversationTriage; aqui só se GRAVA a decisão, com auditoria (triaged_by).
#
# NÃO cria tarefa, NÃO cria TimeEntry, NÃO toca ConversationLink/personal: só status de
# revisão (open/reviewed/ignored) e confirmação de cliente/projeto em campos próprios.
class ConversationTriagesController < ApplicationController
  before_action :set_conversation

  def update
    @triage = ConversationTriageDecision.find_or_initialize_by(conversation: @conversation)
    authorize @triage
    apply_changes(@triage)
    @triage.triaged_by = current_user

    if @triage.save
      redirect_to redirect_target, notice: "Triagem atualizada."
    else
      redirect_to redirect_target, alert: @triage.errors.full_messages.to_sentence.presence || "Não foi possível atualizar a triagem."
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  # Aplica só o que veio pela lista permitida; ignora valores inválidos (não estoura).
  def apply_changes(triage)
    apply_status(triage)
    apply_client(triage)
    apply_project(triage)
    triage.note = params[:note] if params.key?(:note)
  end

  def apply_status(triage)
    status = params[:status]
    triage.status = status if ConversationTriageDecision::STATUSES.include?(status)
  end

  # confirmar cliente: só aceita id de cliente EXISTENTE; "" limpa a confirmação.
  def apply_client(triage)
    return unless params.key?(:confirmed_client_id)

    id = params[:confirmed_client_id].presence
    triage.confirmed_client = id && Client.find_by(id: id)
    triage.confirmed_project = nil if triage.confirmed_client.nil? # projeto sem cliente não faz sentido
  end

  def apply_project(triage)
    return unless params.key?(:confirmed_project_id)

    id = params[:confirmed_project_id].presence
    triage.confirmed_project = id && Project.find_by(id: id)
  end

  # Volta para onde veio (detalhe em modo triagem por padrão); return_to sanitizado.
  def redirect_target
    return_to_param.presence || conversation_path(@conversation, mode: "triage")
  end
end
