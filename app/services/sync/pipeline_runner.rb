require "open3"

module Sync
  # PB-016a — executa o PIPELINE EXTERNO (Python/RepoB) de forma segura, a partir
  # de uma SyncExecution. NUNCA recebe path/argumento do usuário: executável,
  # script e diretório vêm SOMENTE de configuração/ENV (allowlist).
  #
  # Segurança:
  #  - `Open3.capture3` com ARRAY de argumentos → nenhum shell intermediário
  #    (sem interpolação/`/bin/sh -c`), imune a metacaracteres;
  #  - comando fixo `[python, script]` validado (existência do script + dir);
  #  - timeout fixo configurável: ao estourar, mata o processo (KILL) e marca timeout;
  #  - captura LIMITADA de stdout/stderr (últimas linhas, com teto de bytes);
  #  - resumo seguro: sem paths absolutos, sem conteúdo de conversa/segredos;
  #  - exit code != 0 ⇒ ok? = false (a orquestração não importa).
  #
  # Injetável: a orquestração pode passar outro runner em teste (jamais roda o
  # pipeline real na suíte).
  class PipelineRunner
    MAX_CAPTURE_BYTES = 8 * 1024 # teto de captura por stream (stdout/stderr)
    SUMMARY_TAIL_LINES = 8       # últimas linhas mantidas no resumo seguro

    Result = Struct.new(:ok, :exit_code, :timed_out, :summary, keyword_init: true) do
      def ok? = ok
    end

    def self.call(...) = new(...).call

    def initialize(python: nil, script: nil, dir: nil, timeout: nil)
      cfg = Rails.application.config.x
      @python  = (python  || cfg.pipeline_python).to_s
      @script  = (script  || cfg.pipeline_script).to_s
      @dir     = (dir     || cfg.pipeline_dir).to_s
      @timeout = (timeout || cfg.pipeline_timeout).to_i
    end

    def call
      missing = validate_env
      return failure("Ambiente do pipeline inválido: #{missing}.", exit_code: nil) if missing

      run
    rescue StandardError => e
      failure(safe(e.message), exit_code: nil)
    end

    private

    # Allowlist: script e diretório precisam existir; comando é fixo (sem input).
    # O executável pode ser um nome no PATH (ex.: "python") ou um caminho absoluto.
    def validate_env
      return "script ausente" unless File.file?(@script)
      return "diretório ausente" unless File.directory?(@dir)
      return "executável ausente" if @python.blank?

      nil
    end

    def run
      out = +""
      err = +""
      status = nil
      timed_out = false

      # ARRAY de args → sem shell. chdir no diretório do pipeline.
      Open3.popen3(@python, @script, chdir: @dir) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        readers = { stdout => out, stderr => err }
        deadline = monotonic + @timeout

        until readers.empty?
          remaining = deadline - monotonic
          if remaining <= 0
            timed_out = true
            kill(wait_thr.pid)
            break
          end
          ready, = IO.select(readers.keys, nil, nil, [ remaining, 1 ].min)
          next unless ready

          ready.each do |io|
            chunk = io.read_nonblock(4096, exception: false)
            if chunk.nil? || chunk == :wait_readable
              readers.delete(io) if chunk.nil?
              next
            end
            buf = readers[io]
            buf << chunk if buf.bytesize < MAX_CAPTURE_BYTES
          end
        end

        status = wait_thr.value
      end

      return failure("Pipeline excedeu o tempo limite (#{@timeout}s).", exit_code: nil, timed_out: true) if timed_out

      code = status&.exitstatus
      if code.zero?
        Result.new(ok: true, exit_code: 0, timed_out: false, summary: summarize(out, err, 0))
      else
        Result.new(ok: false, exit_code: code, timed_out: false, summary: summarize(out, err, code))
      end
    end

    def kill(pid)
      Process.kill("KILL", pid)
    rescue StandardError
      nil
    end

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Resumo seguro p/ a UI/registro: só as últimas linhas, sem paths absolutos.
    def summarize(out, err, code)
      tail = (err.presence || out).to_s.lines.last(SUMMARY_TAIL_LINES).join.strip
      msg = "exit=#{code}"
      msg += " · #{safe(tail)}" if tail.present?
      msg[0, 500]
    end

    # Remove diretórios absolutos (Unix e Windows) p/ não vazar paths/segredos.
    def safe(text)
      text.to_s
          .gsub(%r{/[^\s]*/}, "…/")
          .gsub(/[A-Za-z]:\\[^\s]*/, "…\\")
          .strip
    end

    def failure(message, exit_code:, timed_out: false)
      Result.new(ok: false, exit_code: exit_code, timed_out: timed_out, summary: message[0, 500])
    end
  end
end
