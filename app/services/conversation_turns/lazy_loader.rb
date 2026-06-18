require "json"
require "digest"

module ConversationTurns
  # Leitura lazy de turnos via índice de offsets (ADR-021). Lê APENAS as linhas
  # da conversa por `seek(byte_offset)`; não varre linha-a-linha para localizar
  # turnos (o fingerprint usa só janelas do arquivo); nunca grava conteúdo.
  # Retorna payloads em memória (para a F5 renderizar com sanitização — ADR-012).
  #
  # NÃO é usado em request web sobre o arquivo de 229 MiB sem índice: depende de
  # `conversation_turn_refs` já construído e do fingerprint vigente.
  class LazyLoader
    # Redação de PII em caminhos (padrão F3.3/ADR-020): /Users/<nome> → /Users/<USER>.
    USER_PATH = %r{([/\\](?:Users|home)[/\\])[^/\\]+}i

    Turn = Struct.new(
      :line_no, :role, :ts, :text, :tool, :tool_input, :files_changed,
      :model_id, :agent_name, :source_file, keyword_init: true
    )
    Result = Struct.new(
      :status, :turns, :total, :limit, :offset, :mismatched, :turn_source,
      keyword_init: true
    )

    def self.call(conversation_id:, limit: nil, offset: 0, path: nil)
      new(conversation_id: conversation_id, limit: limit, offset: offset, path: path).call
    end

    def initialize(conversation_id:, limit: nil, offset: 0, path: nil)
      @conversation_id = conversation_id
      @limit = limit
      @offset = offset.to_i
      @path = path
    end

    def call
      conversation = Conversation.find_by(id: @conversation_id)
      return result(:not_found) if conversation.nil?

      base = ConversationTurnRef.where(conversation_id: conversation.id)
      total = base.count
      source = base.includes(:turn_source).order(:line_no).first&.turn_source
      return result(:empty, total: 0) if source.nil?

      file_path = (@path || source.source_file).to_s
      return result(:stale, total: total, turn_source: source) unless fingerprint_ok?(source, file_path)

      turns, mismatched = read_turns(base, source, conversation, file_path)
      result(:ok, turns: turns, total: total, mismatched: mismatched, turn_source: source)
    end

    private

    def read_turns(base, source, conversation, file_path)
      refs = base.where(turn_source_id: source.id).order(:line_no)
      refs = refs.offset(@offset) if @offset.positive?
      refs = refs.limit(@limit) if @limit
      refs = refs.to_a

      turns = []
      mismatched = 0
      File.open(file_path, "rb") do |f|
        refs.each do |ref|
          f.seek(ref.byte_offset)
          raw = f.gets
          next if raw.nil?

          parsed = parse_line(raw.force_encoding("UTF-8"))
          next if parsed.nil?

          # Defesa contra offset obsoleto: a linha lida tem que ser desta conversa.
          if parsed["thread_id"] != conversation.thread_id
            mismatched += 1
            next
          end

          turns << build_turn(ref, parsed)
        end
      end
      [ turns, mismatched ]
    end

    def build_turn(ref, parsed)
      Turn.new(
        line_no: ref.line_no,
        role: parsed["role"],
        ts: parsed["timestamp"],
        text: parsed["text"],
        tool: parsed["tool"],
        tool_input: parsed["tool_input"],
        files_changed: Array(parsed["files_changed"]),
        model_id: parsed["model_id"],
        agent_name: parsed["agent_name"],
        source_file: redact(parsed["raw_source_file"])
      )
    end

    # Confere o fingerprint atual do arquivo contra o turn_source (size + hash parcial
    # + schema). Divergência ⇒ índice obsoleto (não lê).
    def fingerprint_ok?(source, file_path)
      return false unless File.exist?(file_path)
      return false unless source.schema_version == Sync::BuildConversationTurnRefs::CONTRACT_VERSION

      size = File.size(file_path)
      return false unless size == source.size_bytes

      partial_hash(file_path, size) == source.content_hash
    end

    def partial_hash(file_path, size)
      window = Sync::BuildConversationTurnRefs::HASH_WINDOW
      digest = Digest::SHA256.new
      File.open(file_path, "rb") do |f|
        if size <= window * 2
          # Arquivo pequeno: lê no máximo window*2 bytes (bounded; nunca o arquivo todo
          # de forma ilimitada). Mesmo resultado do builder, que também lê só `size` bytes aqui.
          digest.update(f.read(window * 2))
        else
          digest.update(f.read(window))
          f.seek(size - window)
          digest.update(f.read(window))
        end
      end
      digest.hexdigest
    end

    def redact(value)
      return nil if value.blank?

      value.to_s.gsub(USER_PATH, '\1<USER>')
    end

    def parse_line(line)
      parsed = JSON.parse(line)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def result(status, turns: [], total: 0, mismatched: 0, turn_source: nil)
      Result.new(status: status, turns: turns, total: total, limit: @limit,
                 offset: @offset, mismatched: mismatched, turn_source: turn_source)
    end
  end
end
