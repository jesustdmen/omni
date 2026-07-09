# PB-023e — barra de filtros avançados, reutilizável por todas as listas.
#
# Renderiza, num único form GET (Turbo/Hotwire), a busca textual (opcional) e
# um **combobox multi-seleção estilo "token input"** por critério: chips dentro
# do campo, busca ao digitar e menu de opções (Stimulus `combobox`). A base é
# um `<select multiple name="key[]">` — fonte de verdade do form E fallback
# funcional sem JS. Params multi-valor seguem a convenção Rails `key[]=a&key[]=b`;
# a leitura/sanitização por allowlist fica no controller (concern MultiFilter).
class FilterBarComponent < ViewComponent::Base
  # filters: Array de Hash { key:, label:, options: [[label, value], ...],
  #   selected: [value, ...] }
  def initialize(url:, query:, filters:, search: nil, per_page: nil, extra: {}, submit_label: "Filtrar")
    @url = url
    @query = normalize_query(query)
    @filters = filters
    @search = search
    @per_page = per_page
    @extra = extra.transform_keys(&:to_s)
    @submit_label = submit_label
  end

  # Alguma coisa buscada/selecionada? (controla o "Limpar filtros")
  def any_active?
    @search&.dig(:value).present? || @filters.any? { |f| Array(f[:selected]).any? }
  end

  # "Limpar filtros": mantém só os params neutros (ex.: aba), zera o resto.
  def clear_url
    build_url(@extra.dup)
  end

  # Hidden fields que sobrevivem ao submit do form (ex.: tab).
  def hidden_extra
    @extra
  end

  private

  def normalize_query(query)
    if query.respond_to?(:to_unsafe_h)
      query.to_unsafe_h.stringify_keys
    else
      query.to_h.stringify_keys
    end
  end

  def build_url(query)
    query = query.reject { |_k, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
    query.empty? ? @url : "#{@url}?#{query.to_query}"
  end
end
