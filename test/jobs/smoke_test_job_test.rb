require "test_helper"

class SmokeTestJobTest < ActiveJob::TestCase
  test "executa de forma síncrona e retorna a mensagem" do
    assert_equal "smoke-ok: world", SmokeTestJob.perform_now
  end

  test "pode ser enfileirado" do
    assert_enqueued_with(job: SmokeTestJob) do
      SmokeTestJob.perform_later("x")
    end
  end
end
