require "json"

module Conversations
  # F5.1/F5.2 — render READ-ONLY de turnos (ADR-021 + ADR-012).
  # Recebe o ConversationTurns::LazyLoader::Result e renderiza com segurança:
  # o `text` é redigido (PII), truncado e convertido a HTML SEGURO de markdown via
  # ConversationTurns::MarkdownRenderer (única fonte de html_safe); tool_input SEMPRE
  # como texto em <pre> (nunca markdown/HTML); role por allowlist; source_file NÃO é
  # exibido; conteúdo truncado por teto de bytes. O componente em si NÃO usa
  # html_safe/raw/sanitize (delega ao renderer) — grep-guard mantido.
  class TurnListComponent < ViewComponent::Base
    include PaginationHelper # navegação amigável (primeira/anterior/próxima/última)

    ALLOWED_ROLES = %w[user assistant system tool].freeze
    # Tom do badge por role (apenas apresentação; valores fixos — sem injeção).
    ROLE_TONES = { "user" => "info", "assistant" => "violet", "tool" => "neutral", "system" => "warning" }.freeze
    TEXT_LIMIT = 20_000        # bytes máx de texto por turno (anti-DoS de render)
    TOOL_INPUT_LIMIT = 4_000   # bytes máx de tool_input por turno

    def initialize(result:, conversation:, page: 1, total_pages: 1, per_page: nil, per_page_options: [])
      @result = result
      @conversation = conversation
      @page = page
      @total_pages = total_pages
      @per_page = per_page
      @per_page_options = per_page_options
    end

    def status
      @result&.status
    end

    def turns
      Array(@result&.turns)
    end

    def total
      @result&.total.to_i
    end

    def mismatched
      @result&.mismatched.to_i
    end

    # role seguro (allowlist) — usado em classe CSS e rótulo; valor fora da lista vira "unknown".
    def role_class(role)
      ALLOWED_ROLES.include?(role.to_s) ? role.to_s : "unknown"
    end

    def role_label(role)
      role_class(role).humanize
    end

    # Tom do badge (allowlist via role_class → valor fixo do mapa).
    def role_tone(role)
      ROLE_TONES.fetch(role_class(role), "neutral")
    end

    def timestamp_label(value)
      return "—" if value.blank?

      t = value.is_a?(String) ? (Time.iso8601(value) rescue nil) : value
      t ? t.strftime("%d/%m/%Y %H:%M") : value.to_s
    end

    # Texto redigido (PII) e truncado — base (texto puro) para o markdown.
    def turn_text(turn)
      truncate_bytes(ConversationTurns::PiiRedactor.call(turn.text.to_s), TEXT_LIMIT)
    end

    # F5.2 — markdown sanitizado (HTML seguro) do texto já redigido/truncado.
    def turn_body_html(turn)
      ConversationTurns::MarkdownRenderer.call(turn_text(turn))
    end

    def tool_input?(turn)
      turn.tool.present? || turn.tool_input.present?
    end

    # tool_input SEMPRE como texto (nunca HTML). JSON seguro com fallback e truncamento.
    def tool_input_text(turn)
      serialized =
        case turn.tool_input
        when nil then ""
        when String then turn.tool_input
        else json_safe(turn.tool_input)
        end
      truncate_bytes(ConversationTurns::PiiRedactor.call(serialized), TOOL_INPUT_LIMIT)
    end

    def page_url(target)
      helpers.conversation_path(@conversation, turn_page: target, turn_per_page: @per_page, anchor: "conversa")
    end

    # URL para trocar o tamanho da página (volta à página 1).
    def per_page_url(size)
      helpers.conversation_path(@conversation, turn_page: 1, turn_per_page: size, anchor: "conversa")
    end

    attr_reader :page, :total_pages, :per_page, :per_page_options

    private

    def json_safe(value)
      JSON.pretty_generate(value)
    rescue StandardError
      value.inspect
    end

    def truncate_bytes(str, limit)
      s = str.to_s
      return s if s.bytesize <= limit

      "#{s.byteslice(0, limit).scrub('')}… (truncado)"
    end
  end
end
