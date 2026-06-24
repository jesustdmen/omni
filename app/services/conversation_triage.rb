# PB-020 (Triagem) — estado de triagem DERIVADO read-only de uma conversa.
#
# Nesta fatia NÃO há tabela/persistência de triagem (decisão do PO): o estado é
# calculado a partir do que já existe — vínculos (`ConversationLink`), `personal`,
# e o casamento workspace→cliente (`workspace_maps.folder` × `clients.workspace_paths`).
# Toda sugestão de cliente é RASCUNHO e exige confirmação humana (sem decisão automática).
#
# Estados derivados (string):
#   linked    — já tem vínculo a tarefa (triagem "resolvida")
#   personal  — marcada como pessoal (ADR-013): parece não ser trabalho
#   suggested — sem vínculo, sem `personal`, com cliente sugerível por workspace
#   noclient  — sem vínculo, sem `personal`, sem cliente sugerível (workspace não bate)
#   pending   — sem vínculo, sem `personal`, ainda não classificável (fallback)
#
# Uso eficiente em lote: `ConversationTriage.index_for(conversations)` pré-carrega
# os mapas (1 query cada) e devolve um Hash conversation_id => Result (sem N+1).
class ConversationTriage
  STATES = %w[linked personal suggested noclient pending].freeze
  LABELS = {
    "linked" => "Vinculada", "personal" => "Pessoal", "suggested" => "Cliente sugerido",
    "noclient" => "Sem cliente", "pending" => "Pendente"
  }.freeze

  Result = Struct.new(:state, :suggested_client, :folder, keyword_init: true) do
    def label = LABELS.fetch(state, state)
    def linked? = state == "linked"
    def suggested? = state == "suggested"
    def noclient? = state == "noclient"
  end

  # Mapa conversation_id => Result para uma coleção (sem N+1).
  def self.index_for(conversations)
    convs = conversations.to_a
    return {} if convs.empty?

    folders = WorkspaceMap.where.not(folder: nil).pluck(:workspace_hash, :folder).to_h
    linked_ids = ConversationLink.where(conversation_id: convs.map(&:id)).distinct.pluck(:conversation_id).to_set
    client_index = build_client_index # folder(normalizado) => Client

    convs.each_with_object({}) do |c, acc|
      acc[c.id] = derive(c, folders: folders, linked_ids: linked_ids, client_index: client_index)
    end
  end

  # Estado de uma única conversa (usa os mesmos mapas; aceita injeção p/ teste/lote).
  def self.derive(conversation, folders: nil, linked_ids: nil, client_index: nil)
    folders ||= WorkspaceMap.where.not(folder: nil).pluck(:workspace_hash, :folder).to_h
    linked_ids ||= ConversationLink.where(conversation_id: conversation.id).distinct.pluck(:conversation_id).to_set
    client_index ||= build_client_index

    folder = folders[conversation.workspace_hash]
    suggested = folder && client_index[normalize(folder)]

    state =
      if linked_ids.include?(conversation.id) then "linked"
      elsif conversation.personal then "personal"
      elsif suggested then "suggested"
      elsif folder.nil? then "noclient" # workspace não resolvido → ninguém sabe o cliente
      else "pending" # workspace resolvido, mas sem cliente casado
      end

    Result.new(state: state, suggested_client: suggested, folder: folder)
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
end
