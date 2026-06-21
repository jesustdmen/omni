require "test_helper"

class SyncConversationsJobTest < ActiveJob::TestCase
  # Substitui Sync::RunConversationsSync.call por um espião, restaurando ao fim.
  def with_spy
    calls = []
    original = Sync::RunConversationsSync.method(:call)
    Sync::RunConversationsSync.define_singleton_method(:call) { |execution:| calls << execution }
    yield calls
  ensure
    Sync::RunConversationsSync.singleton_class.send(:remove_method, :call)
    Sync::RunConversationsSync.define_singleton_method(:call, original)
  end

  test "executa o serviço para uma execução ativa" do
    exec = SyncExecution.create!(status: "queued", trigger: "manual")
    with_spy do |calls|
      SyncConversationsJob.perform_now(exec.id)
      assert_equal [ exec.id ], calls.map(&:id)
    end
  end

  test "no-op se a execução não existe" do
    with_spy do |calls|
      assert_nothing_raised { SyncConversationsJob.perform_now("00000000-0000-0000-0000-000000000000") }
      assert_empty calls
    end
  end

  test "no-op se a execução não está ativa (já concluída)" do
    exec = SyncExecution.create!(status: "ok", trigger: "manual")
    with_spy do |calls|
      SyncConversationsJob.perform_now(exec.id)
      assert_empty calls, "não deve reprocessar execução já finalizada"
    end
  end
end
