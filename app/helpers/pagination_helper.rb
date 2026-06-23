# Paginação amigável e consistente em todo o app (listas + turnos da conversa).
# Renderiza: « Primeira · ‹ Anterior · "Página X de Y · N item(s)" · Próxima › · Última »
#
# `url:` é uma lambda Ruby (NÃO um bloco ERB) que recebe o nº da página e devolve a
# URL daquela página — quem chama controla o path e a preservação de query params:
#
#   <%= pagination_nav(current: @page, total_pages: @total_pages, total_count: @total_count,
#         unit: "tarefa(s)", url: ->(p) { tasks_path(request.query_parameters.merge(page: p)) }) %>
module PaginationHelper
  def pagination_nav(current:, total_pages:, url:, total_count: nil, unit: "registro(s)", aria: "Paginação")
    current = current.to_i
    total_pages = [ total_pages.to_i, 1 ].max
    return "".html_safe if total_pages <= 1 && total_count.nil?

    controls = safe_join([
      pg_edge("« Primeira", url.call(1), enabled: current > 1, rel: "first"),
      pg_edge("‹ Anterior", url.call(current - 1), enabled: current > 1, rel: "prev"),
      tag.span(pg_summary(current, total_pages, total_count, unit), class: "pagination__status"),
      pg_edge("Próxima ›", url.call(current + 1), enabled: current < total_pages, rel: "next"),
      pg_edge("Última »", url.call(total_pages), enabled: current < total_pages, rel: "last")
    ])

    tag.nav(tag.span(controls, class: "pagination__controls"), class: "pagination", aria: { label: aria })
  end

  private

  def pg_summary(current, total_pages, total_count, unit)
    base = "Página #{current} de #{total_pages}"
    total_count.nil? ? base : "#{base} · #{total_count} #{unit}"
  end

  # Quando habilitado, vira link; senão, <span> desabilitado (mantém o layout).
  def pg_edge(label, href, enabled:, rel:)
    if enabled
      link_to(label, href, class: "btn btn--ghost btn--sm pagination__btn", rel: rel)
    else
      tag.span(label, class: "btn btn--ghost btn--sm pagination__btn is-disabled", aria: { disabled: "true" })
    end
  end
end
