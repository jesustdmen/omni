# PB-020 (Triagem) — estado EFETIVO de triagem de uma conversa.
#
# Compõe DUAS fontes, sem dupla verdade (ver docs/PB-020 §D0/§D4):
#   1. DERIVADO (sempre disponível): vínculos (`ConversationLink`), `personal`
#      (conversations.personal) e o casamento workspace→cliente
#      (`workspace_maps.folder` × `clients.workspace_paths`).
#   2. PERSISTIDO (quando há decisão humana — `ConversationTriageDecision`):
#      `status` (open/reviewed/ignored) sobrepõe o fluxo derivado; `confirmed_client`
#      sobrepõe a SUGESTÃO de cliente.
#
# Precedência do estado (string `state`):
#   linked    — tem vínculo a tarefa (derivado de ConversationLink; nunca persistido)
#   personal  — conversations.personal (privacidade; nunca vira status)
#   ignored   — decisão humana status=ignored
#   reviewed  — decisão humana status=reviewed
#   suggested — cliente EFETIVO conhecido (confirmado OU sugerido por workspace)
#   noclient  — workspace não resolvido e sem cliente confirmado
#   pending   — workspace resolvido mas sem cliente (confirmado/sugerido)
#
# `client` no Result é o cliente EFETIVO: confirmado (humano) tem prioridade sobre
# o sugerido (workspace). `client_confirmed?` diz se veio de decisão humana.
class ConversationTriage
  # Chaves internas (símbolos) em inglês por convenção; rótulos PT-BR para a UI.
  STATES = %w[linked personal ignored reviewed suggested noclient pending].freeze
  # Rótulo PT-BR do ESTADO EFETIVO exibido (cards/badges).
  LABELS = {
    "linked" => "Vinculada", "personal" => "Pessoal", "ignored" => "Ignorada",
    "reviewed" => "Revisada", "suggested" => "Cliente sugerido",
    "noclient" => "Sem cliente", "pending" => "Pendente"
  }.freeze
  # Rótulo PT-BR do STATUS PERSISTIDO da decisão de triagem (open/reviewed/ignored).
  STATUS_LABELS = { "open" => "Aberta", "reviewed" => "Revisada", "ignored" => "Ignorada" }.freeze

  Result = Struct.new(
    :state, :client, :folder, :client_confirmed, :confirmed_project, :persisted_status, :note,
    keyword_init: true
  ) do
    def label = LABELS.fetch(state, state)
    def linked? = state == "linked"
    def suggested? = state == "suggested"
    def noclient? = state == "noclient"
    def reviewed? = state == "reviewed"
    def ignored? = state == "ignored"
    def persisted? = persisted_status.present?
    # Rótulo PT-BR do status persistido (evita vazar a chave interna p/ a tela).
    def persisted_status_label = STATUS_LABELS.fetch(persisted_status, persisted_status)
    def client_confirmed? = client_confirmed == true
    # Cliente exibido como mera SUGESTÃO (workspace) — pede confirmação humana.
    def client_suggested? = client.present? && !client_confirmed?
  end

  # Mapa conversation_id => Result para uma coleção (sem N+1).
  def self.index_for(conversations)
    convs = conversations.to_a
    return {} if convs.empty?

    folders = WorkspaceMap.where.not(folder: nil).pluck(:workspace_hash, :folder).to_h
    linked_ids = ConversationLink.where(conversation_id: convs.map(&:id)).distinct.pluck(:conversation_id).to_set
    client_index = build_client_index # folder(normalizado) => Client
    decisions = ConversationTriageDecision
                .where(conversation_id: convs.map(&:id))
                .includes(:confirmed_client, :confirmed_project)
                .index_by(&:conversation_id)

    convs.each_with_object({}) do |c, acc|
      acc[c.id] = derive(c, folders: folders, linked_ids: linked_ids,
                            client_index: client_index, decisions: decisions)
    end
  end

  # Estado efetivo de uma única conversa (aceita injeção dos mapas p/ teste/lote).
  def self.derive(conversation, folders: nil, linked_ids: nil, client_index: nil, decisions: nil)
    folders ||= WorkspaceMap.where.not(folder: nil).pluck(:workspace_hash, :folder).to_h
    linked_ids ||= ConversationLink.where(conversation_id: conversation.id).distinct.pluck(:conversation_id).to_set
    client_index ||= build_client_index
    decision = lookup_decision(conversation, decisions)

    folder = folders[conversation.workspace_hash]
    suggested_client = folder && client_index[normalize(folder)]
    confirmed_client = decision&.confirmed_client
    effective_client = confirmed_client || suggested_client

    state = effective_state(conversation, linked_ids, decision, effective_client, folder)

    Result.new(
      state: state, client: effective_client, folder: folder,
      client_confirmed: confirmed_client.present?,
      confirmed_project: decision&.confirmed_project,
      persisted_status: decision&.status, note: decision&.note
    )
  end

  # folder normalizado => Client (a partir de clients.workspace_paths). 1 cliente por
  # folder (o primeiro encontrado; colisão é improvável e não decide nada sozinha).
  def self.build_client_index
    index = {}
    Client.where.not(workspace_paths: []).select(:id, :name, :workspace_paths).each do |client|
      Array(client.workspace_paths).each do |path|
        key = normalize(path)
        index[key] ||= client unless key.blank?
      end
    end
    index
  end

  # Casamento tolerante: minúsculas, separadores normalizados, sem barra final.
  def self.normalize(path)
    path.to_s.strip.downcase.tr("\\", "/").chomp("/")
  end

  # Precedência: derivados fortes (linked/personal) > decisão de fluxo (ignored/reviewed)
  # > estado por cliente efetivo (suggested) > derivados de workspace (noclient/pending).
  def self.effective_state(conversation, linked_ids, decision, effective_client, folder)
    return "linked" if linked_ids.include?(conversation.id)
    return "personal" if conversation.personal
    return "ignored" if decision&.status == "ignored"
    return "reviewed" if decision&.status == "reviewed"
    return "suggested" if effective_client # confirmado ou sugerido
    return "noclient" if folder.nil? # workspace não resolvido
    "pending" # workspace resolvido, mas sem cliente
  end

  def self.lookup_decision(conversation, decisions)
    return decisions[conversation.id] if decisions
    return conversation.triage if conversation.association(:triage).loaded?

    ConversationTriageDecision.find_by(conversation_id: conversation.id)
  end
  private_class_method :effective_state, :lookup_decision
end
