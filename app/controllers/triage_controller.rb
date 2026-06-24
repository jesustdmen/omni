# PB-020 (Triagem) — Inbox/Central de Triagem de conversas (read-only nesta fatia).
# Deriva o estado de cada conversa (sem tabela de triagem — ver ConversationTriage),
# monta os cards por estado, a fila principal e a fila "sem cliente". As AÇÕES por
# linha reaproveitam telas existentes (abrir conversa, criar tarefa a partir dela,
# vincular) — nenhuma decisão automática, nenhuma escrita aqui.
class TriageController < ApplicationController
  QUEUE_LIMIT = 25 # itens exibidos na fila principal (sem paginação nesta fatia)

  def index
    @state = params[:state].presence_in(ConversationTriage::STATES)

    # Base: conversas mais recentes primeiro. Estados derivados em lote (sem N+1).
    base = Conversation.order(Arel.sql("last_ts DESC NULLS LAST, updated_at DESC"))
    recent = base.limit(300).to_a # janela de trabalho da inbox (as mais recentes)
    @triage = ConversationTriage.index_for(recent)

    @counts = Hash.new(0)
    recent.each { |c| @counts[@triage[c.id].state] += 1 }
    @counts[:total] = recent.size

    pending_like = recent.reject { |c| @triage[c.id].linked? || @triage[c.id].state == "personal" }
    @no_client = pending_like.select { |c| @triage[c.id].noclient? }

    queue = @state ? recent.select { |c| @triage[c.id].state == @state } : pending_like
    @queue = queue.first(QUEUE_LIMIT)
    @queue_total = queue.size

    @folders = WorkspaceMap.pluck(:workspace_hash, :folder).to_h
    @last_sync = SyncRun.order(:created_at).last
  end
end
