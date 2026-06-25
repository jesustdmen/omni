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

  # PB-020 (Triagem) — ação MANUAL: pede sugestões de atividades à IA local
  # (Ollama/Gemma4) e grava cada uma como RASCUNHO (source ia_local). Nada é
  # confirmado automaticamente; a revisão é humana. Falha da IA NÃO estoura:
  # volta à Triagem com mensagem clara e o fluxo manual segue normal.
  def suggest
    authorize @conversation.activity_drafts.new, :suggest?

    # Privacidade (ADR-013): conversa pessoal não vai para a IA nesta fatia.
    if @conversation.personal
      return redirect_to triage_target,
                         alert: "Conversa pessoal: a sugestão por IA está desativada para proteger o conteúdo. Use as atividades manuais."
    end

    result = Ai::SuggestConversationActivities.call(conversation: @conversation)

    if result.sem_contexto?
      redirect_to triage_target,
                  alert: "Não há contexto textual suficiente para sugerir atividades com segurança."
    elsif result.falhou?
      redirect_to triage_target,
                  alert: "Não foi possível obter sugestões da IA local agora. A Triagem manual continua disponível."
    elsif result.atividades.empty?
      redirect_to triage_target, notice: "A IA local não sugeriu atividades para esta conversa."
    else
      total = criar_rascunhos_da_ia(result.atividades)
      redirect_to triage_target,
                  notice: "#{total} atividade(s) sugerida(s) pela IA adicionada(s) como rascunho. Revise e confirme ou descarte."
    end
  end

  private

  # Grava as atividades sugeridas como RASCUNHO (source ia_local), de forma atômica.
  # Evidência/confiança da IA vão na descrição para o humano revisar (auditável).
  def criar_rascunhos_da_ia(atividades)
    base = next_position
    ConversationActivityDraft.transaction do
      atividades.each_with_index do |atividade, indice|
        @conversation.activity_drafts.create!(
          title: atividade.titulo,
          description: descricao_sugerida(atividade),
          status: "draft",
          source: "ia_local",
          position: base + indice,
          created_by: current_user,
          updated_by: current_user
        )
      end
    end
    atividades.size
  end

  # Junta descrição + evidência + confiança da IA (quando houver) para revisão humana.
  def descricao_sugerida(atividade)
    partes = []
    partes << atividade.descricao if atividade.descricao.present?
    partes << "Evidência: #{atividade.evidencia}" if atividade.evidencia.present?
    partes << "Confiança: #{atividade.confianca}" if atividade.confianca.present?
    partes.join("\n").presence
  end

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
