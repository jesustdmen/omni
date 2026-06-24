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

  def status_badge(value, tone: nil, label: nil)
    return "—" if value.blank?

    key = value.to_s.downcase
    tone ||= STATUS_TONES.fetch(key, :neutral)
    # `label:` permite exibir um rótulo PT-BR mantendo o tom pela key (ex.: Demanda).
    text = label.presence || value.to_s.humanize
    tag.span(text, class: "badge badge--#{tone}")
  end

  # PB-018 — badge de status CONFIGURÁVEL (Tarefas/Projetos): usa o rótulo PT-BR e a
  # COR definidos na tabela `configurable_statuses`. A cor NÃO vai por `style` inline
  # (bloqueado pela CSP restrita — ADR-012), e sim por uma CLASSE
  # `cfg-status--<entity>-<key>` cujas regras são emitidas num `<style nonce>`
  # (ver `configurable_status_styles_tag`, incluído no layout). `final` acrescenta
  # uma classe utilitária (só apresentação). Status sem registro cai no badge tonal.
  def configurable_status_badge(entity, key)
    return "—" if key.blank?

    row = configurable_statuses_for(entity)[key.to_s]
    return status_badge(key) if row.nil? # registro órfão (não deveria ocorrer): degrade

    classes = [ "badge", "badge--config", configurable_status_class(entity, row.key) ]
    classes << "badge--final" if row.final?
    tag.span(row.name, class: classes.join(" "),
                       title: (row.final? ? "Status finalizador" : nil))
  end

  # PB-018 — bloco <style> (com nonce, aceito pela CSP) com a cor de cada status
  # configurado de Tarefas e Projetos. Renderizado UMA vez no layout. Sem style
  # inline → compatível com `style-src 'self' 'nonce-…'`. Os valores hex são
  # validados no model (allowlist de formato); ainda assim sanitizamos aqui.
  def configurable_status_styles_tag
    rows = ConfigurableStatus.all.to_a
    return "".html_safe if rows.empty?

    css = rows.filter_map do |s|
      color = sanitize_hex(s.color)
      next if color.nil?

      sel = ".#{configurable_status_class(s.entity_type, s.key)}"
      "#{sel}{background:#{hex_to_rgba(color, 0.14)};color:#{color};border-color:#{color};}"
    end.join("\n")

    # Usa o nonce REAL da requisição (o mesmo do header CSP) — `nonce: true` não
    # resolve aqui. content_security_policy_nonce vem do helper do Rails.
    tag.style(css.html_safe, nonce: content_security_policy_nonce) # rubocop:disable Rails/OutputSafety
  end

  private

  # Classe CSS estável e segura por status (só [a-z0-9_] do key; entity fixo).
  def configurable_status_class(entity, key)
    safe_key = key.to_s.gsub(/[^a-z0-9_]/, "")
    "cfg-status--#{entity}-#{safe_key}"
  end

  # Aceita só "#rgb"/"#rrggbb"; devolve a forma longa "#rrggbb" ou nil (descarta).
  def sanitize_hex(hex)
    h = hex.to_s.strip.delete("#").downcase
    h = h.chars.map { |c| c * 2 }.join if h.length == 3
    return nil unless h.match?(/\A\h{6}\z/)

    "##{h}"
  end

  # Converte "#rrggbb" para "rgba(r,g,b,alpha)" (fundo tonal do badge).
  def hex_to_rgba(hex, alpha)
    h = hex.to_s.delete("#")
    r, g, b = h.scan(/../).map { |p| p.to_i(16) }
    "rgba(#{r},#{g},#{b},#{alpha})"
  end

  # Cache por request: 1 query por entidade exibida (evita N+1 nos badges da lista).
  def configurable_statuses_for(entity)
    @configurable_statuses_cache ||= {}
    @configurable_statuses_cache[entity.to_s] ||=
      ConfigurableStatus.for_entity(entity).index_by(&:key)
  end

  public

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

  # Exibição de data/hora no timezone OPERACIONAL (Brasília — config.time_zone),
  # independente de o instante estar armazenado em UTC (ADR-023). Use estes helpers
  # em vez de `strftime` direto em horários relevantes (TimeEntry etc.).
  DATETIME_FMT = "%d/%m/%Y %H:%M".freeze
  TIME_FMT     = "%H:%M".freeze

  # Data + hora local: "17/06/2026 09:00" (ou um placeholder quando nil).
  def local_datetime(value, placeholder: "—")
    return placeholder if value.blank?

    value.in_time_zone.strftime(DATETIME_FMT)
  end

  # Só a hora local: "09:00".
  def local_time(value, placeholder: "—")
    return placeholder if value.blank?

    value.in_time_zone.strftime(TIME_FMT)
  end

  # Só a data local (para cabeçalho de agrupamento por dia): "17/06/2026".
  def local_date(value, placeholder: "—")
    return placeholder if value.blank?

    # `value` pode ser Date (já no dia operacional, derivado no model) ou Time.
    (value.respond_to?(:in_time_zone) ? value.in_time_zone : value).strftime("%d/%m/%Y")
  end
end
