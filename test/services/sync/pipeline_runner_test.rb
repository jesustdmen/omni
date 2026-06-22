require "test_helper"
require "tmpdir"
require "fileutils"

module Sync
  # PB-016a — testa o runner do pipeline SEM jamais executar o pipeline real.
  # Usa scripts triviais de teste (sh) que apenas escrevem em stdout/stderr e
  # saem com um código — exercitando Open3 (array, sem shell), timeout, exit code
  # e a captura/limite/redação, mas nunca o RepoB.
  class PipelineRunnerTest < ActiveSupport::TestCase
    setup do
      @dir = Dir.mktmpdir("pipe")
    end

    teardown { FileUtils.remove_entry(@dir) if Dir.exist?(@dir) }

    # Cria um "executável" (sh) que roda o corpo dado e sai com `code`.
    def script(body, code: 0, name: "fake.sh")
      path = File.join(@dir, name)
      File.write(path, "#!/usr/bin/env bash\n#{body}\nexit #{code}\n")
      FileUtils.chmod(0o755, path)
      path
    end

    def run_pipe(script_path, timeout: 30)
      PipelineRunner.new(python: "bash", script: script_path, dir: @dir, timeout: timeout).call
    end

    test "sucesso: exit 0 → ok?" do
      r = run_pipe(script("echo done", code: 0))
      assert r.ok?
      assert_equal 0, r.exit_code
      refute r.timed_out
    end

    test "exit code != 0 → falha com o código" do
      r = run_pipe(script("echo boom 1>&2", code: 3))
      refute r.ok?
      assert_equal 3, r.exit_code
      assert_match(/exit=3/, r.summary)
    end

    test "timeout: processo longo é morto e marcado timed_out" do
      r = run_pipe(script("sleep 5", code: 0), timeout: 1)
      refute r.ok?
      assert r.timed_out
      assert_match(/tempo limite/i, r.summary)
    end

    test "ambiente inválido: script ausente → falha sem executar" do
      r = PipelineRunner.new(python: "bash", script: File.join(@dir, "nao_existe.sh"), dir: @dir).call
      refute r.ok?
      assert_match(/inválido/i, r.summary)
    end

    test "captura é limitada (não explode a memória) e resumo é curto" do
      # imprime muito mais que o teto de captura; o summary fica curto.
      r = run_pipe(script("for i in $(seq 1 100000); do echo linha-$i; done", code: 0))
      assert r.ok?
      assert_operator r.summary.bytesize, :<=, 500
    end

    test "resumo seguro: não vaza caminhos absolutos" do
      r = run_pipe(script("echo erro em /home/secreto/arquivo.py 1>&2", code: 4))
      refute r.ok?
      assert_no_match(%r{/home/secreto/}, r.summary)
    end

    test "comando é fixo (array): metacaracteres do nome não viram shell" do
      # se houvesse shell, '; touch pwned' executaria; com array, é só argumento.
      pwned = File.join(@dir, "pwned")
      r = PipelineRunner.new(python: "bash", script: "x; touch #{pwned}", dir: @dir).call
      refute r.ok? # script inexistente (validação) — e nada foi criado
      refute File.exist?(pwned), "nenhum shell deve ter interpretado o ';'"
    end
  end
end
