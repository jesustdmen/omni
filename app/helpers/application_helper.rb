module ApplicationHelper
  # Pílula visual de status / tipo / prioridade. Apenas apresentação — escrita
  # do zero (sem copiar nada das referências). Mapeia valores conhecidos do
  # domínio para um "tom" de cor; valores fora do mapa ficam neutros.
  STATUS_TONES = {
    # status de trabalho
    "todo" => :neutral, "pending" => :neutral, "planning" => :neutral, "backlog" => :neutral,
    "in_progress" => :info, "doing" => :info, "active" => :info, "review" => :info,
    "done" => :success, "completed" => :success, "converted" => :success, "closed" => :success,
    "blocked" => :danger, "canceled" => :danger, "cancelled" => :danger,
    # prioridades
    "low" => :neutral, "medium" => :warning, "high" => :danger
  }.freeze

  def status_badge(value, tone: nil)
    return "—" if value.blank?

    key = value.to_s.downcase
    tone ||= STATUS_TONES.fetch(key, :neutral)
    tag.span(value.to_s.humanize, class: "badge badge--#{tone}")
  end
end
