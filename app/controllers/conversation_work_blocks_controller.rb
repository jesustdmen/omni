# PB-020d (Triagem) — rascunhos de blocos de trabalho (turno/dia) de uma conversa.
# Aninhado em /conversations/:conversation_id/work_blocks. Itens SEMPRE escopados pela
# conversa da URL (impede manipular bloco de outra conversa cruzando IDs). Volta sempre
# ao detalhe em modo triagem. NÃO cria Task/TimeEntry, NÃO toca ConversationLink,
# NÃO promove a TimeEntry.
class ConversationWorkBlocksController < ApplicationController
  before_action :set_conversation
  # PB-020d — conversa pessoal não participa: bloqueia criar/editar (destroy/limpeza segue).
  before_action :block_personal_conversation, only: %i[create update]
  before_action :set_block, only: %i[update destroy]

  def create
    @block = @conversation.work_blocks.new(create_params)
    @block.created_by = current_user
    @block.updated_by = current_user
    @block.position ||= next_position
    authorize @block
    if @block.save
      redirect_to triage_target, notice: "Bloco de trabalho adicionado."
    else
      redirect_to triage_target, alert: error_message(@block, "Não foi possível adicionar o bloco.")
    end
  end

  def update
    @block.assign_attributes(update_params)
    @block.updated_by = current_user
    if @block.save
      redirect_to triage_target, notice: "Bloco de trabalho atualizado."
    else
      redirect_to triage_target, alert: error_message(@block, "Não foi possível atualizar o bloco.")
    end
  end

  def destroy
    @block.destroy
    redirect_to triage_target, notice: "Bloco de trabalho removido."
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  # PB-020d — conversa pessoal não gera/edita blocos (regra de produto). Backend, não só UI.
  def block_personal_conversation
    return unless @conversation.personal?

    redirect_to triage_target,
                alert: "Conversa marcada como pessoal. Blocos de trabalho não são gerados para conversas pessoais."
  end

  # Escopado pela conversa da URL: bloco de outra conversa → 404 (não vaza).
  def set_block
    @block = @conversation.work_blocks.find(params[:id])
    authorize @block
  end

  # Criação: campos manuais. status/kind/source/position têm default seguro no banco/model.
  def create_params
    params.require(:work_block).permit(*editable_attrs)
  end

  # Atualização: campos editáveis + mudança de status pela lista permitida.
  # `status` inválido é descartado (não estoura, não grava valor livre).
  def update_params
    permitted = params.require(:work_block).permit(*editable_attrs, :status)
    permitted.delete(:status) unless ConversationWorkBlock::STATUSES.include?(permitted[:status])
    permitted
  end

  # NÃO inclui `source` (manual por default; IA é fatia futura) nem auditoria.
  def editable_attrs
    %i[period_date day_period start_time end_time duration_seconds kind
       summary notes needs_external_evidence external_evidence_note
       client_id project_id task_id]
  end

  def next_position
    (@conversation.work_blocks.maximum(:position) || -1) + 1
  end

  def triage_target
    conversation_path(@conversation, mode: "triage", anchor: "blocos")
  end

  def error_message(block, fallback)
    block.errors.full_messages.to_sentence.presence || fallback
  end
end
