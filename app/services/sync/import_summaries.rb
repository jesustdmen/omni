require "json"

module Sync
  # Importa metadados de conversa a partir de `summaries.jsonl` (saída normalizada
  # do RepoB — ADR-008), de forma idempotente por `thread_id` e em streaming.
  #
  # NÃO lê `sessions.jsonl`/turnos (ADR-018), não toca o pipeline, não importa
  # dados reais por conta própria (o chamador informa os caminhos).
  class ImportSummaries
    # Versão de contrato registrada por execução (ver F3_CONTRACT_DECISIONS.md).
    # Alinhada ao _SHARD_SCHEMA_VERSION observado no pipeline.
    CONTRACT_VERSION = "4"
    EXCERPT_LIMIT = 300

    def self.call(summaries_path:, titles_path: nil, workspace_maps_path: nil)
      new(summaries_path: summaries_path, titles_path: titles_path, workspace_maps_path: workspace_maps_path).call
    end

    def initialize(summaries_path:, titles_path: nil, workspace_maps_path: nil)
      @summaries_path = summaries_path.to_s
      @titles_path = titles_path&.to_s
      @workspace_maps_path = workspace_maps_path&.to_s
    end

    def call
      run = SyncRun.create!(
        source_label: "summaries.jsonl",
        source_file: @summaries_path,
        source_mtime: file_mtime(@summaries_path),
        schema_version: CONTRACT_VERSION,
        status: "ok",
        started_at: Time.current
      )

      titles = load_json_hash(@titles_path)
      ws_map = load_json_hash(@workspace_maps_path)
      counters = { lines_processed: 0, imported: 0, updated: 0, skipped: 0, error_lines: 0 }

      begin
        aggregates = aggregate_lines(run, counters)
        persist(aggregates, titles, ws_map, counters)
        status = counters[:error_lines].positive? || counters[:skipped].positive? ? "partial" : "ok"
        run.update!(counters.merge(status: status, finished_at: Time.current))
      rescue StandardError => e
        run.update(status: "error", finished_at: Time.current, **counters)
        raise e
      end

      run
    end

    private

    # --- streaming + acumulação em memória por thread_id -------------------
    def aggregate_lines(run, counters)
      aggregates = {}
      File.foreach(@summaries_path).with_index(1) do |line, line_number|
        next if line.strip.empty?

        counters[:lines_processed] += 1
        parsed = parse_line(line)

        if parsed.nil?
          counters[:error_lines] += 1
          run.items.create!(line_number: line_number, status: "error", reason: "JSON inválido", raw_excerpt: excerpt(line))
          next
        end

        thread_id = parsed["thread_id"].presence
        if thread_id.nil?
          counters[:skipped] += 1
          run.items.create!(line_number: line_number, status: "skipped", reason: "sem thread_id", raw_excerpt: excerpt(line))
          next
        end

        aggregates[thread_id] = fold(aggregates[thread_id] || blank_acc, normalize(parsed))
      end
      aggregates
    end

    # --- persistência idempotente -----------------------------------------
    def persist(aggregates, titles, ws_map, counters)
      ActiveRecord::Base.transaction do
        upsert_known_workspaces(ws_map)

        aggregates.each do |thread_id, agg|
          conversation = Conversation.find_by(thread_id: thread_id)
          existed = conversation.present?
          conversation ||= Conversation.new(thread_id: thread_id)

          merged = fold(acc_from(conversation), agg)
          assign(conversation, merged, titles[thread_id])
          conversation.save!

          existed ? counters[:updated] += 1 : counters[:imported] += 1
          ensure_workspace_map(conversation.workspace_hash)
        end
      end
    end

    # --- regra de merge determinística (F3_CONTRACT_DECISIONS §3) ----------
    def blank_acc
      { first_ts: nil, last_ts: nil, message_count: 0, user_turns: 0, assistant_turns: 0,
        tool_calls: 0, files_changed: [], session_id: nil, source: nil, workspace_hash: nil, title: nil }
    end

    def fold(acc, rec)
      newer = newer_ts?(rec[:last_ts], acc[:last_ts])
      acc[:first_ts]        = min_ts(acc[:first_ts], rec[:first_ts])
      acc[:message_count]   = [ acc[:message_count], rec[:message_count] ].max
      acc[:user_turns]      = [ acc[:user_turns], rec[:user_turns] ].max
      acc[:assistant_turns] = [ acc[:assistant_turns], rec[:assistant_turns] ].max
      acc[:tool_calls]      = [ acc[:tool_calls], rec[:tool_calls] ].max
      acc[:files_changed]   = (acc[:files_changed] | rec[:files_changed]).sort
      if newer
        acc[:session_id]     = rec[:session_id]
        acc[:source]         = rec[:source]
        acc[:workspace_hash] = rec[:workspace_hash]
        acc[:title]          = rec[:title]
      end
      acc[:last_ts] = max_ts(acc[:last_ts], rec[:last_ts])
      acc
    end

    def normalize(parsed)
      { first_ts: parse_ts(parsed["first_ts"]),
        last_ts: parse_ts(parsed["last_ts"]),
        message_count: parsed["message_count"].to_i,
        user_turns: parsed["user_turns"].to_i,
        assistant_turns: parsed["assistant_turns"].to_i,
        tool_calls: parsed["tool_calls"].to_i,
        files_changed: Array(parsed["files_changed"]).map(&:to_s),
        session_id: parsed["session_id"].presence,
        source: parsed["source"].presence,
        workspace_hash: parsed["workspace_hash"].presence,
        title: parsed["title"].presence }
    end

    def acc_from(conversation)
      { first_ts: conversation.first_ts, last_ts: conversation.last_ts,
        message_count: conversation.message_count, user_turns: conversation.user_turns,
        assistant_turns: conversation.assistant_turns, tool_calls: conversation.tool_calls,
        files_changed: Array(conversation.files_changed), session_id: conversation.session_id,
        source: conversation.source, workspace_hash: conversation.workspace_hash, title: conversation.title }
    end

    def assign(conversation, merged, canonical_title)
      conversation.assign_attributes(
        first_ts: merged[:first_ts], last_ts: merged[:last_ts],
        message_count: merged[:message_count], user_turns: merged[:user_turns],
        assistant_turns: merged[:assistant_turns], tool_calls: merged[:tool_calls],
        files_changed: merged[:files_changed], session_id: merged[:session_id],
        source: merged[:source], workspace_hash: merged[:workspace_hash],
        # título canônico (session_titles.json) sobrescreve; senão fallback de linha.
        title: canonical_title.presence || merged[:title]
      )
    end

    # --- workspace maps ----------------------------------------------------
    def upsert_known_workspaces(ws_map)
      ws_map.each do |hash, folder|
        wm = WorkspaceMap.find_or_initialize_by(workspace_hash: hash)
        wm.folder = folder
        wm.save!
      end
    end

    def ensure_workspace_map(hash)
      return if hash.blank?

      # Cria a linha se o workspace foi visto mas não mapeado (folder nil ⇒ órfão).
      WorkspaceMap.find_or_create_by!(workspace_hash: hash)
    end

    # --- helpers -----------------------------------------------------------
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

    def newer_ts?(candidate, current)
      candidate.present? && (current.nil? || candidate > current)
    end

    def min_ts(a, b) = [ a, b ].compact.min
    def max_ts(a, b) = [ a, b ].compact.max

    def excerpt(line) = line.to_s.strip[0, EXCERPT_LIMIT]

    def file_mtime(path)
      File.exist?(path) ? File.mtime(path) : nil
    end

    def load_json_hash(path)
      return {} if path.blank? || !File.exist?(path)

      parsed = JSON.parse(File.read(path))
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end
  end
end
