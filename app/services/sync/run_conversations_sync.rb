require "digest"

module Sync
  # PB-015 — orquestrador operacional da sincronização de conversas.
  #
  # Lê APENAS do diretório fixo/allowlisted (`config.x.normalized_dir`, montado :ro
  # como /normalized). NUNCA aceita path/comando do usuário e NUNCA executa o pipeline
  # Python (ADR-007/008/011) — só consome `output/normalized/`.
  #
  # Ordem obrigatória: (1) ImportSummaries → (2) BuildConversationTurnRefs.
  # ResolveWorkspaceFolders é COMPLEMENTAR: roda só se a fonte fixa existir/estiver
  # montada (não bloqueia o MVP).
  #
  # Integridade:
  #  - advisory lock no Postgres serializa execuções concorrentes;
  #  - "settle + verify": fingerprint do sessions.jsonl é lido ANTES e DEPOIS da
  #    importação; se o arquivo mudou no intervalo, a execução é marcada como erro
  #    e o índice anterior é PRESERVADO (BuildConversationTurnRefs só apaga versões
  #    antigas após concluir com ok/partial);
  #  - falha → último índice válido permanece; SyncExecution registra status/erro.
  #
  # Preservação: ImportSummaries faz upsert por thread_id e NUNCA deleta conversas;
  # tarefas e conversation_links (FK por conversation/thread) são preservados.
  class RunConversationsSync
    # Chave estável p/ pg_advisory_xact_lock (mesmo valor em todo processo/worker).
    ADVISORY_LOCK_KEY = 0x0B015_5172  # "PB015 sync"
    SUMMARIES = "summaries.jsonl".freeze
    SESSIONS  = "sessions.jsonl".freeze
    TITLES    = "session_titles.json".freeze
    WS_MAPS   = "workspace_maps.json".freeze

    Result = Struct.new(:ok, :status, :error, :execution, keyword_init: true) do
      def success? = ok
    end

    def self.call(execution:, pipeline_runner: nil, skip_pipeline: false)
      new(execution: execution, pipeline_runner: pipeline_runner, skip_pipeline: skip_pipeline).call
    end

    # `pipeline_runner` é injetável (testes NUNCA rodam o pipeline real). Quando nil
    # e o pipeline interno está habilitado, usa Sync::PipelineRunner (ENV/allowlist).
    # `skip_pipeline:` força pular a coleta (opção "Importar arquivos disponíveis").
    def initialize(execution:, pipeline_runner: nil, skip_pipeline: false)
      @execution = execution
      @dir = Rails.application.config.x.normalized_dir.to_s
      @pipeline_runner = pipeline_runner
      @skip_pipeline = skip_pipeline
    end

    def call
      # Serializa execuções concorrentes (segunda camada além do índice único de
      # execução ativa). Session-level lock: liberado no `ensure`, na mesma conexão.
      return failure("Outra sincronização já está em andamento.") unless try_advisory_lock

      begin
        @execution.update!(status: "running", started_at: Time.current, error_message: nil,
                           current_step: "starting")

        # PB-016a — etapa 1: PIPELINE EXTERNO (coleta + normalização), se habilitado.
        # Falha/timeout do pipeline ABORTA antes de qualquer importação (índice preservado).
        return pipeline_failure_result unless run_pipeline_step

        summaries = path(SUMMARIES)
        sessions  = path(SESSIONS)
        # PB-016a — confere os arquivos normalizados ANTES de importar.
        set_step("verifying")
        ensure_present!(summaries, sessions)

        # Snapshot do fingerprint ANTES (detecta reescrita durante a leitura).
        fp_before = fingerprint(sessions)

        set_step("importing")
        import_run = Sync::ImportSummaries.call(
          summaries_path: summaries,
          titles_path: optional(TITLES),
          workspace_maps_path: optional(WS_MAPS)
        )
        import_run.update!(sync_execution_id: @execution.id)

        set_step("indexing")
        build_report = Sync::BuildConversationTurnRefs.call(path: sessions)
        link_latest_build_run

        # Verifica DEPOIS: se o sessions.jsonl mudou durante a leitura, o índice pode
        # estar inconsistente → erro, preservando o índice anterior (o build novo só
        # substitui versões antigas após concluir com ok/partial).
        fp_after = fingerprint(sessions)
        if fp_before != fp_after
          return finish_error("Arquivo de origem foi reescrito durante a importação; tente novamente.")
        end

        status = aggregate_status(import_run, build_report)
        @execution.update!(status: status, finished_at: Time.current, current_step: "completed")
        Result.new(ok: true, status: status, error: nil, execution: @execution)
      rescue StandardError => e
        finish_error(safe_message(e))
      ensure
        release_advisory_lock
      end
    end

    private

    # --- PB-016a: pipeline externo (coleta + normalização) -------------------
    # Roda só quando habilitado por config (run_pipeline_internally). Retorna true
    # para prosseguir com a importação; false aborta (execução marcada error).
    def run_pipeline_step
      return true unless pipeline_enabled?

      set_step("collecting")
      result = pipeline_runner.call
      @execution.update!(pipeline_exit_code: result.exit_code, pipeline_summary: result.summary)
      return true if result.ok?

      finish_error(pipeline_error_message(result))
      false
    end

    def pipeline_enabled?
      return false if @skip_pipeline

      Rails.application.config.x.run_pipeline_internally
    end

    # Usa o runner injetado (testes) ou o real (Sync::PipelineRunner, ENV/allowlist).
    def pipeline_runner
      @pipeline_runner ||= Sync::PipelineRunner.new
    end

    def pipeline_error_message(result)
      return "O pipeline excedeu o tempo limite; nenhuma conversa foi importada." if result.timed_out

      "O pipeline falhou (#{result.summary}); nenhuma conversa foi importada."
    end

    def pipeline_failure_result
      Result.new(ok: false, status: "error", error: @execution.error_message, execution: @execution)
    end

    def set_step(step)
      @execution.update!(current_step: step)
    end

    # --- lock ----------------------------------------------------------------
    def try_advisory_lock
      # Lock de sessão não-bloqueante (falha rápido em concorrência). Cast explícito
      # para bigint: a chave excede int4 e a função só existe na assinatura bigint.
      ActiveRecord::Base.connection.select_value(
        "SELECT pg_try_advisory_lock(#{ADVISORY_LOCK_KEY}::bigint)"
      )
    end

    def release_advisory_lock
      ActiveRecord::Base.connection.select_value(
        "SELECT pg_advisory_unlock(#{ADVISORY_LOCK_KEY}::bigint)"
      )
    rescue StandardError
      nil
    end

    # --- paths (allowlist) ---------------------------------------------------
    def path(name)
      File.join(@dir, name)
    end

    def optional(name)
      p = path(name)
      File.exist?(p) ? p : nil
    end

    def ensure_present!(*required)
      missing = required.reject { |p| File.exist?(p) }
      return if missing.empty?

      raise IOError, "Arquivos do output normalizado ausentes: #{missing.map { |m| File.basename(m) }.join(', ')}"
    end

    # --- fingerprint (settle/verify) -----------------------------------------
    # Mesmo critério do índice (size + mtime + hash de cabeça/miolo/cauda).
    def fingerprint(file)
      size = File.size(file)
      mtime = File.mtime(file).utc.iso8601
      "#{size}:#{mtime}:#{partial_hash(file, size)}"
    end

    WINDOW = 64 * 1024
    def partial_hash(file, size)
      d = Digest::SHA256.new
      File.open(file, "rb") do |f|
        if size <= WINDOW * 3
          d.update(f.read)
        else
          d.update(f.read(WINDOW))
          f.seek((size - WINDOW) / 2)
          d.update(f.read(WINDOW))
          f.seek(size - WINDOW)
          d.update(f.read(WINDOW))
        end
      end
      d.hexdigest
    end

    # --- status / encerramento ----------------------------------------------
    def aggregate_status(import_run, build_report)
      parts = [ import_run.status.to_s, build_report.status.to_s ]
      return "error" if parts.include?("error")
      return "partial" if parts.include?("partial")

      "ok"
    end

    def link_latest_build_run
      # O BuildConversationTurnRefs registra um SyncRun próprio (source_label
      # "sessions.jsonl"); vincula o mais recente a esta execução.
      run = SyncRun.where(source_label: SESSIONS, sync_execution_id: nil)
                   .order(created_at: :desc).first
      run&.update!(sync_execution_id: @execution.id)
    end

    def finish_error(message)
      @execution.update!(status: "error", finished_at: Time.current, error_message: message,
                         current_step: "error")
      Result.new(ok: false, status: "error", error: message, execution: @execution)
    end

    def failure(message)
      Result.new(ok: false, status: @execution.status, error: message, execution: @execution)
    end

    # Mensagem segura: sem paths completos, sem conteúdo de conversa.
    def safe_message(error)
      msg = error.message.to_s
      msg = msg.gsub(%r{/[^\s]*/}, "…/") # remove diretórios absolutos
      msg[0, 300]
    end
  end
end
