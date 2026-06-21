# PB-013 — busca global sobre os dados funcionais do Omni. Apenas leitura;
# qualquer usuário autenticado (ADR-014, domínio compartilhado). Resultados
# agrupados por categoria, com badge de tipo e "Encontrado em".
class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @groups = @query.present? ? GlobalSearch.call(query: @query, user: current_user) : []
    # PB-013 — mapa workspace_hash→folder das conversas exibidas (sem N+1 no helper).
    @workspace_folders = workspace_folders_for(@groups)
    # PB-013 — destino do "Voltar": a tela de onde a busca foi acionada (referer
    # interno; nunca a própria busca), com fallback no Dashboard.
    @back_path = safe_back_path
  end

  private

  # Só aceita referer da MESMA origem e que não seja a própria /search (evita loop).
  def safe_back_path
    referer = request.referer
    return root_path if referer.blank?

    uri = URI.parse(referer)
    same_origin = uri.host == request.host && uri.port == request.port
    return root_path unless same_origin
    return root_path if uri.path == request.path # veio da própria busca

    [ uri.path, uri.query ].compact.join("?")
  rescue URI::InvalidURIError
    root_path
  end

  def workspace_folders_for(groups)
    convs = groups.find { |g| g.key == "conversations" }&.hits&.map(&:record) || []
    hashes = convs.map(&:workspace_hash).compact.uniq
    return {} if hashes.empty?

    WorkspaceMap.where(workspace_hash: hashes).pluck(:workspace_hash, :folder).to_h
  end
end
