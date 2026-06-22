require "net/http"
require "json"
require "uri"

module Sync
  # PB-016a — dispara o PIPELINE EXTERNO (Python/RepoB) via o AGENTE no HOST.
  #
  # Por que via agente: o pipeline é Windows-nativo (lê %APPDATA%/.codex/.claude e
  # exige APPDATA); o Omni roda em container Linux. Em vez de montar o perfil no
  # container, o Omni chama o agente (script/pipeline_agent.py) por HTTP local; o
  # agente executa o pipeline no ambiente nativo e devolve só exit code + resumo
  # seguro. Depois o Omni importa /normalized (fluxo PB-015).
  #
  # Segurança: URL/token/timeout vêm de config/ENV (allowlist); o cliente NÃO passa
  # comando/path — o agente tem o comando FIXO. Token compartilhado em todo request.
  #
  # Resiliência (decisão do PO): se o agente estiver OFFLINE, NÃO falha a
  # sincronização — sinaliza `agent_offline` para a orquestração degradar (pula a
  # coleta e importa o /normalized atual, com aviso). Coleta é upgrade opcional;
  # importação é o que sempre deve funcionar.
  #
  # Injetável: a orquestração pode passar outro runner em teste (jamais bate na rede).
  class PipelineRunner
    OPEN_TIMEOUT = 5 # conexão ao agente (rápido p/ detectar offline)

    Result = Struct.new(:ok, :exit_code, :timed_out, :agent_offline, :summary, keyword_init: true) do
      def ok? = ok
      def agent_offline? = agent_offline
    end

    def self.call(...) = new(...).call

    def initialize(agent_url: nil, token: nil, timeout: nil, skip_ingest: false)
      cfg = Rails.application.config.x
      @agent_url = (agent_url || cfg.pipeline_agent_url).to_s
      @token     = (token     || cfg.pipeline_agent_token).to_s
      @timeout   = (timeout   || cfg.pipeline_timeout).to_i
      @skip_ingest = skip_ingest
    end

    def call
      return offline("Agente de coleta indisponível (sem URL configurada).") if @agent_url.blank?
      return offline("Agente de coleta offline.") unless agent_healthy?

      run
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout
      offline("Agente de coleta offline (sem resposta).")
    rescue Net::ReadTimeout
      Result.new(ok: false, exit_code: nil, timed_out: true, agent_offline: false,
                 summary: "Pipeline excedeu o tempo limite (#{@timeout}s).")
    rescue StandardError => e
      Result.new(ok: false, exit_code: nil, timed_out: false, agent_offline: false,
                 summary: safe(e.message))
    end

    private

    # /health não exige token; confirma agente vivo + runner presente.
    def agent_healthy?
      res = http.get(uri("/health").request_uri)
      return false unless res.is_a?(Net::HTTPSuccess)

      body = JSON.parse(res.body) rescue {}
      body["ok"] == true && body["runner_present"] != false
    rescue StandardError
      false
    end

    def run
      req = Net::HTTP::Post.new(uri("/run").request_uri)
      req["X-Agent-Token"] = @token
      req["Content-Type"] = "application/json"
      req.body = { skip_ingest: @skip_ingest }.to_json

      res = http.request(req)
      data = JSON.parse(res.body) rescue {}

      if res.is_a?(Net::HTTPSuccess)
        Result.new(ok: data["ok"] == true, exit_code: data["exit_code"],
                   timed_out: data["timed_out"] == true, agent_offline: false,
                   summary: safe(data["summary"].to_s))
      else
        # 409 (já rodando), 401 (token), etc. — falha de coleta, não offline.
        Result.new(ok: false, exit_code: nil, timed_out: false, agent_offline: false,
                   summary: "Agente recusou a execução (HTTP #{res.code}).")
      end
    end

    def http
      u = uri("/")
      h = Net::HTTP.new(u.host, u.port)
      h.open_timeout = OPEN_TIMEOUT
      h.read_timeout = [ @timeout, 1 ].max
      h
    end

    def uri(path) = URI.join(@agent_url, path)

    def offline(message)
      Result.new(ok: false, exit_code: nil, timed_out: false, agent_offline: true, summary: message)
    end

    # Remove paths absolutos (Unix/Windows) e limita tamanho — sem vazar paths/segredos.
    def safe(text)
      text.to_s.gsub(%r{/[^\s]*/}, "…/").gsub(/[A-Za-z]:\\[^\s]*/, "…\\").strip[0, 500]
    end
  end
end
