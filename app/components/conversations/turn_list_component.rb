require "json"

module Conversations
  # F5.1 — render READ-ONLY de turnos (ADR-021 + ADR-012).
  # Recebe o ConversationTurns::LazyLoader::Result e renderiza com segurança:
  # somente texto auto-escapado (a view usa <%= %>); tool_input SEMPRE como texto
  # em <pre> (nunca HTML); role por allowlist; source_file NÃO é exibido; conteúdo
  # truncado por teto de bytes. NÃO usa html_safe/raw/markdown/auto-link.
  class TurnListComponent < ViewComponent::Base
    ALLOWED_ROLES = %w[user assistant system tool].freeze
    TEXT_LIMIT = 20_000        # bytes máx de texto por turno (anti-DoS de render)
    TOOL_INPUT_LIMIT = 4_000   # bytes máx de tool_input por turno

    def initialize(result:, conversation:, page: 1, total_pages: 1)
      @result = result
      @conversation = conversation
      @page = page
      @total_pages = total_pages
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

    def timestamp_label(value)
      return "—" if value.blank?

      t = value.is_a?(String) ? (Time.iso8601(value) rescue nil) : value
      t ? t.strftime("%d/%m/%Y %H:%M") : value.to_s
    end

    def turn_text(turn)
      truncate_bytes(turn.text.to_s, TEXT_LIMIT)
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
      truncate_bytes(serialized, TOOL_INPUT_LIMIT)
    end

    def page_url(target)
      helpers.conversation_path(@conversation, turn_page: target, anchor: "conversa")
    end

    attr_reader :page, :total_pages

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
