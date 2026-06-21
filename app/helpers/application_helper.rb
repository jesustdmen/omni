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

  # PB-003a — ícones inline (estilo lucide, autorados; sem copiar de _origem).
  # Construídos com tag-builders (sem html_safe/raw). `aria-hidden` — o nome
  # acessível vem do aria-label/title do botão que contém o ícone.
  ACTION_ICONS = {
    "eye" => [
      [ :path, { d: "M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" } ],
      [ :circle, { cx: 12, cy: 12, r: 3 } ]
    ],
    "pencil" => [
      [ :path, { d: "M12 20h9" } ],
      [ :path, { d: "M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4Z" } ]
    ],
    "trash" => [
      [ :path, { d: "M3 6h18" } ],
      [ :path, { d: "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" } ],
      [ :line, { x1: 10, x2: 10, y1: 11, y2: 17 } ],
      [ :line, { x1: 14, x2: 14, y1: 11, y2: 17 } ]
    ],
    "stop" => [ [ :rect, { x: 6, y: 6, width: 12, height: 12, rx: 2 } ] ],
    "play" => [ [ :polygon, { points: "6 3 20 12 6 21 6 3" } ] ]
  }.freeze

  # PB-006 — formata CNPJ (14 dígitos) como NN.NNN.NNN/NNNN-NN; senão devolve cru/—.
  def format_cnpj(value)
    digits = value.to_s.gsub(/\D/, "")
    return value.presence || "—" unless digits.length == 14

    digits.sub(/\A(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})\z/, '\1.\2.\3/\4-\5')
  end

  # PB-003c — contagem de timers em andamento (no máximo 1 query COUNT por página;
  # memoizada). Sem consulta por item.
  def running_timers_count
    @running_timers_count ||= TimeEntry.running.count
  end

  def action_icon(name)
    children = ACTION_ICONS.fetch(name.to_s, [])
    tag.svg(
      width: 16, height: 16, viewBox: "0 0 24 24", fill: "none",
      stroke: "currentColor", "stroke-width": 2, "stroke-linecap": "round",
      "stroke-linejoin": "round", "aria-hidden": "true", class: "icon"
    ) do
      safe_join(children.map { |element, attrs| tag.public_send(element, "", **attrs) })
    end
  end

  # Formata uma duração inteira **em segundos** (unidade canônica — PB-003) para um
  # rótulo legível: "—", "0 min", "42 s", "1 min 30 s", "1 h", "1 h 30 min".
  # Segundos só aparecem quando < 1 h (precisão de timers curtos).
  def duration_label(value)
    return "—" if value.blank?

    seconds = value.to_i
    return "0 min" if seconds <= 0

    hours, rem = seconds.divmod(3600)
    minutes, secs = rem.divmod(60)
    parts = []
    parts << "#{hours} h" if hours.positive?
    parts << "#{minutes} min" if minutes.positive?
    parts << "#{secs} s" if secs.positive? && hours.zero?
    parts.join(" ").presence || "0 min"
  end
end
