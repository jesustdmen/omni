# PB-013 — busca global sobre os dados funcionais do Omni. Apenas leitura;
# qualquer usuário autenticado (ADR-014, domínio compartilhado). Resultados
# agrupados por categoria, com badge de tipo e "Encontrado em".
class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @groups = @query.present? ? GlobalSearch.call(query: @query, user: current_user) : []
    # PB-013 — mapa workspace_hash→folder das conversas exibidas (sem N+1 no helper).
    @workspace_folders = workspace_folders_for(@groups)
    # PB-013 — destino do "Voltar": referer interno seguro (mecanismo secundário,
    # via concern central), com fallback no Dashboard. Anti-loop já tratado.
    @back_path = safe_referer_back(fallback: root_path)
  end

  private

  def workspace_folders_for(groups)
    convs = groups.find { |g| g.key == "conversations" }&.hits&.map(&:record) || []
    hashes = convs.map(&:workspace_hash).compact.uniq
    return {} if hashes.empty?

    WorkspaceMap.where(workspace_hash: hashes).pluck(:workspace_hash, :folder).to_h
  end
end
