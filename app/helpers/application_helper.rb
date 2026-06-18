module ApplicationHelper
  # Pílula visual de status / tipo / prioridade. Apenas apresentação — escrita
  # do zero. Cores alinhadas ao hi-fi (`_mockup/spec-hifi.jsx`): status
  # (active=verde, pending=âmbar, in_progress=azul, completed/done=violeta,
  # cancelled=vermelho) e tipo (support=ciano, questions=violeta,
  # implementation=âmbar, development=azul, commercial=rosa). Fora do mapa = neutro.
  STATUS_TONES = {
    # status de trabalho
    "active" => :success, "pending" => :warning, "todo" => :neutral, "planning" => :neutral,
    "backlog" => :neutral, "in_progress" => :info, "doing" => :info, "review" => :info,
    "done" => :violet, "completed" => :violet, "closed" => :violet, "converted" => :success,
    "blocked" => :danger, "canceled" => :danger, "cancelled" => :danger,
    # prioridades
    "low" => :neutral, "medium" => :warning, "high" => :danger,
    # tipos de tarefa
    "support" => :cyan, "question" => :violet, "questions" => :violet,
    "implementation" => :warning, "development" => :info, "commercial" => :pink,
    # status de sync (F3.UI.1)
    "ok" => :success, "partial" => :warning, "error" => :danger
  }.freeze

  def status_badge(value, tone: nil)
    return "—" if value.blank?

    key = value.to_s.downcase
    tone ||= STATUS_TONES.fetch(key, :neutral)
    tag.span(value.to_s.humanize, class: "badge badge--#{tone}")
  end

  # Nome de arquivo SEGURO para exibir em telas (sem path/PII). Retorna só o
  # basename, lidando com separadores "/" e "\" e com o esquema "file://".
  # Garante que caminhos locais (/normalized, /tmp, /home, C:\Users, file:///…)
  # nunca apareçam na UI — só o nome do arquivo (ex.: "sessions.jsonl").
  def safe_basename(value)
    return "—" if value.blank?

    cleaned = value.to_s.sub(%r{\Afile://}i, "")
    cleaned.split(%r{[/\\]}).last.presence || "—"
  end

  # Formata uma duração inteira (em minutos — unidade a confirmar na carga real,
  # ver F3_CONTRACT_DECISIONS.md) para um rótulo legível: "—", "0 min", "45 min",
  # "1 h", "1 h 30 min".
  def duration_label(value)
    return "—" if value.blank?

    minutes = value.to_i
    return "0 min" if minutes <= 0

    hours, mins = minutes.divmod(60)
    parts = []
    parts << "#{hours} h" if hours.positive?
    parts << "#{mins} min" if mins.positive?
    parts.join(" ")
  end
end
