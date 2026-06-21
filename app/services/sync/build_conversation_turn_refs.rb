require "json"
require "digest"

module Sync
  # Constrói o índice de turnos (offsets) a partir de `sessions.jsonl` — ADR-021.
  #
  # Guarda APENAS ponteiros (turn_source + conversation_turn_refs): nunca `text`,
  # nunca `tool_input`, nunca payload. Streaming + idempotente por fingerprint do arquivo.
  # NÃO lê shards, NÃO renderiza, NÃO toca `ImportSummaries`/`ResolveWorkspaceFolders`.
  class BuildConversationTurnRefs
    CONTRACT_VERSION = "4"     # alinhado ao _SHARD_SCHEMA_VERSION do pipeline
    SOURCE_LABEL = "sessions.jsonl"
    BATCH = 5_000
    HASH_WINDOW = 64 * 1024    # bytes de cabeça + cauda para o hash parcial

    Report = Struct.new(
      :lines_processed, :refs_created, :refs_updated, :skipped_no_thread,
      :skipped_no_conversation, :malformed_lines, :distinct_threads,
      :covered_conversations, :source_fingerprint, :status, :turn_source, :no_op,
      keyword_init: true
    )

    def self.call(path:)
      new(path: path).call
    end

    def initialize(path:)
      @path = path.to_s
    end

    def call
      raise ArgumentError, "arquivo não encontrado: #{@path}" unless File.exist?(@path)

      fp = fingerprint

      # PB-015 — `source_mtime` ENTRA na chave de no-op (antes ficava de fora): assim
      # qualquer reescrita do arquivo (mtime muda) invalida o índice mesmo que size e
      # as bordas coincidam. Combinado ao hash de cabeça+miolo+cauda (partial_hash),
      # fecha o falso no-op de "miolo alterado com size/bordas iguais".
      existing = TurnSource.find_by(
        source_file: fp[:source_file], size_bytes: fp[:size_bytes],
        source_mtime: fp[:source_mtime],
        content_hash: fp[:content_hash], schema_version: fp[:schema_version]
      )
      # Build concluído = ok|partial (partial = concluiu com skips/malformados; ainda é
      # um índice completo daquela versão). Mesmo arquivo ⇒ no-op idempotente.
      if existing && %w[ok partial].include?(existing.status) && existing.conversation_turn_refs.exists?
        return no_op_report(existing, fp)
      end

      build(fp)
    end

    private

    # --- build completo (rebuild total por versão de arquivo) ----------------
    def build(fp)
      source = TurnSource.create!(
        source_label: SOURCE_LABEL, source_file: fp[:source_file],
        size_bytes: fp[:size_bytes], source_mtime: fp[:source_mtime],
        content_hash: fp[:content_hash], schema_version: fp[:schema_version],
        status: "pending"
      )

      counters = Hash.new(0)
      distinct = {}            # thread_id => true (apenas presença)
      covered = {}             # conversation_id => true
      conv_map = Conversation.pluck(:thread_id, :id).to_h

      stream(source, conv_map, counters, distinct, covered)

      counters[:distinct_threads] = distinct.size
      counters[:covered_conversations] = covered.size
      status = clean?(counters) ? "ok" : "partial"
      source.update!(status: status, indexed_at: Time.current)

      # Remove versões antigas do mesmo arquivo (cascade remove suas refs no DB).
      TurnSource.where(source_file: fp[:source_file]).where.not(id: source.id).delete_all

      log_sync_run(fp, counters, status)
      report(counters, fp, status, source, no_op: false)
    end

    def stream(source, conv_map, counters, distinct, covered)
      now = Time.current
      buffer = []
      File.open(@path, "rb") do |f|
        line_no = 0
        until f.eof?
          offset = f.pos
          raw = f.gets
          line_no += 1
          next if raw.nil?

          line = raw.force_encoding("UTF-8")
          next if line.strip.empty?

          counters[:lines_processed] += 1
          parsed = parse_line(line)
          if parsed.nil?
            counters[:malformed_lines] += 1
            next
          end

          thread_id = parsed["thread_id"].presence
          if thread_id.nil?
            counters[:skipped_no_thread] += 1
            next
          end
          distinct[thread_id] = true

          conversation_id = conv_map[thread_id]
          if conversation_id.nil?
            counters[:skipped_no_conversation] += 1
            next
          end
          covered[conversation_id] = true

          buffer << {
            turn_source_id: source.id, conversation_id: conversation_id,
            thread_id: thread_id, line_no: line_no, byte_offset: offset,
            role: parsed["role"].presence, ts: parse_ts(parsed["timestamp"]),
            created_at: now, updated_at: now
          }
          if buffer.size >= BATCH
            ConversationTurnRef.insert_all(buffer)
            counters[:refs_created] += buffer.size
            buffer.clear
          end
        end
      end
      unless buffer.empty?
        ConversationTurnRef.insert_all(buffer)
        counters[:refs_created] += buffer.size
      end
    end

    # --- fingerprint ---------------------------------------------------------
    def fingerprint
      size = File.size(@path)
      { source_file: @path, size_bytes: size, source_mtime: File.mtime(@path),
        content_hash: partial_hash(size), schema_version: CONTRACT_VERSION }
    end

    # SHA-256 de (cabeça + MIOLO + cauda) — barato (3 janelas de 64 KiB) e robusto:
    # a amostra do meio (PB-015) elimina o falso no-op de "miolo alterado mantendo
    # size e bordas". Combinado a size+mtime no find_by (ADR-021 §3 + PB-015).
    def partial_hash(size)
      digest = Digest::SHA256.new
      File.open(@path, "rb") do |f|
        if size <= HASH_WINDOW * 3
          digest.update(f.read)
        else
          digest.update(f.read(HASH_WINDOW))           # cabeça
          f.seek((size - HASH_WINDOW) / 2)
          digest.update(f.read(HASH_WINDOW))           # miolo
          f.seek(size - HASH_WINDOW)
          digest.update(f.read(HASH_WINDOW))           # cauda
        end
      end
      digest.hexdigest
    end

    def fingerprint_label(fp)
      "#{fp[:size_bytes]}:#{fp[:source_mtime].utc.iso8601}:#{fp[:content_hash][0, 12]}:v#{fp[:schema_version]}"
    end

    # --- auditoria (SyncRun separado do import de summaries) ------------------
    def log_sync_run(fp, counters, status)
      SyncRun.create!(
        source_label: SOURCE_LABEL, source_file: fp[:source_file],
        source_mtime: fp[:source_mtime], schema_version: fp[:schema_version],
        started_at: Time.current, finished_at: Time.current, status: status,
        lines_processed: counters[:lines_processed], imported: counters[:refs_created],
        updated: counters[:refs_updated],
        skipped: counters[:skipped_no_thread] + counters[:skipped_no_conversation],
        error_lines: counters[:malformed_lines]
      )
    end

    # --- relatórios ----------------------------------------------------------
    def report(counters, fp, status, source, no_op:)
      Report.new(
        lines_processed: counters[:lines_processed], refs_created: counters[:refs_created],
        refs_updated: counters[:refs_updated], skipped_no_thread: counters[:skipped_no_thread],
        skipped_no_conversation: counters[:skipped_no_conversation],
        malformed_lines: counters[:malformed_lines], distinct_threads: counters[:distinct_threads],
        covered_conversations: counters[:covered_conversations],
        source_fingerprint: fingerprint_label(fp), status: status, turn_source: source, no_op: no_op
      )
    end

    def no_op_report(source, fp)
      Report.new(
        lines_processed: 0, refs_created: 0, refs_updated: 0, skipped_no_thread: 0,
        skipped_no_conversation: 0, malformed_lines: 0,
        distinct_threads: source.conversation_turn_refs.distinct.count(:thread_id),
        covered_conversations: source.conversation_turn_refs.distinct.count(:conversation_id),
        source_fingerprint: fingerprint_label(fp), status: "ok", turn_source: source, no_op: true
      )
    end

    def clean?(counters)
      counters[:malformed_lines].zero? &&
        counters[:skipped_no_thread].zero? &&
        counters[:skipped_no_conversation].zero?
    end

    def parse_line(line)
      parsed = JSON.parse(line)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    def parse_ts(value)
      return nil if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
