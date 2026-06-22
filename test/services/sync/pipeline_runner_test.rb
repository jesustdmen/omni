require "test_helper"
require "socket"

module Sync
  # PB-016a — testa o PipelineRunner como CLIENTE HTTP do agente, SEM jamais rodar
  # o pipeline real. Sobe um agente FALSO via TCPServer (stdlib; sem webrick) que
  # responde /health e /run conforme o cenário.
  class PipelineRunnerTest < ActiveSupport::TestCase
    # Mini servidor HTTP em thread. `health:` controla /health; `run_body`/`run_status`
    # controlam /run; exige X-Agent-Token == token em /run.
    def with_fake_agent(health:, run_body:, run_status: 200, token: "t")
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      thread = Thread.new do
        loop do
          client = server.accept
          request_line = client.gets.to_s
          headers = {}
          while (line = client.gets) && line != "\r\n"
            k, v = line.split(":", 2)
            headers[k.strip.downcase] = v.to_s.strip if v
          end
          path = request_line.split(" ")[1].to_s

          status, body =
            if path.start_with?("/health")
              [ health ? 200 : 503, { ok: health, runner_present: true } ]
            elsif path.start_with?("/run")
              headers["x-agent-token"] == token ? [ run_status, run_body ] : [ 401, { ok: false, error: "unauthorized" } ]
            else
              [ 404, { ok: false } ]
            end

          payload = body.to_json
          client.print "HTTP/1.1 #{status} OK\r\nContent-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}"
          client.close
        rescue IOError, Errno::ECONNRESET
          next
        end
      end
      yield "http://127.0.0.1:#{port}", token
    ensure
      thread&.kill
      server&.close
    end

    def runner(url, token, **opts)
      PipelineRunner.new(agent_url: url, token: token, timeout: 10, **opts)
    end

    test "sucesso: agente online e /run exit 0 → ok?" do
      with_fake_agent(health: true, run_body: { ok: true, exit_code: 0, timed_out: false, summary: "exit=0 · ok" }) do |url, token|
        r = runner(url, token).call
        assert r.ok?
        assert_equal 0, r.exit_code
        refute r.agent_offline?
      end
    end

    test "exit code de erro → falha (não offline)" do
      with_fake_agent(health: true, run_body: { ok: false, exit_code: 3, timed_out: false, summary: "exit=3 · boom" }) do |url, token|
        r = runner(url, token).call
        refute r.ok?
        assert_equal 3, r.exit_code
        refute r.agent_offline?
      end
    end

    test "timeout reportado pelo agente → timed_out" do
      with_fake_agent(health: true, run_body: { ok: false, exit_code: nil, timed_out: true, summary: "timeout" }) do |url, token|
        r = runner(url, token).call
        refute r.ok?
        assert r.timed_out
      end
    end

    test "agente offline (health falha) → agent_offline, sem chamar /run" do
      with_fake_agent(health: false, run_body: { ok: true, exit_code: 0 }) do |url, token|
        r = runner(url, token).call
        refute r.ok?
        assert r.agent_offline?, "health falho deve marcar offline"
      end
    end

    test "URL sem agente (conexão recusada) → agent_offline" do
      r = PipelineRunner.new(agent_url: "http://127.0.0.1:1", token: "t", timeout: 2).call
      refute r.ok?
      assert r.agent_offline?
    end

    test "token errado → /run recusa (401), falha não-offline" do
      with_fake_agent(health: true, run_body: { ok: true, exit_code: 0 }, token: "certo") do |url, _token|
        r = runner(url, "errado").call
        refute r.ok?
        refute r.agent_offline?
        assert_match(/recusou/i, r.summary)
      end
    end

    test "URL em branco → offline (não tenta rede)" do
      r = PipelineRunner.new(agent_url: "", token: "t", timeout: 2).call
      assert r.agent_offline?
    end
  end
end
