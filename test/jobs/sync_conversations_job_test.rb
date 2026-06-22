require "test_helper"

class SyncConversationsJobTest < ActiveJob::TestCase
  # Substitui Sync::RunConversationsSync.call por um espião, restaurando ao fim.
  def with_spy
    calls = []
    original = Sync::RunConversationsSync.method(:call)
    # PB-016a — o serviço agora recebe também skip_pipeline (default false).
    Sync::RunConversationsSync.define_singleton_method(:call) do |execution:, skip_pipeline: false, pipeline_runner: nil|
      calls << { execution: execution, skip_pipeline: skip_pipeline }
    end
    yield calls
  ensure
    Sync::RunConversationsSync.singleton_class.send(:remove_method, :call)
    Sync::RunConversationsSync.define_singleton_method(:call, original)
  end

  test "executa o serviço para uma execução ativa" do
    exec = SyncExecution.create!(status: "queued", trigger: "manual")
    with_spy do |calls|
      SyncConversationsJob.perform_now(exec.id)
      assert_equal [ exec.id ], calls.map { |c| c[:execution].id }
      assert_equal [ false ], calls.map { |c| c[:skip_pipeline] }, "default não pula o pipeline"
    end
  end

  test "repassa skip_pipeline ao serviço (PB-016a)" do
    exec = SyncExecution.create!(status: "queued", trigger: "manual_import")
    with_spy do |calls|
      SyncConversationsJob.perform_now(exec.id, skip_pipeline: true)
      assert_equal [ true ], calls.map { |c| c[:skip_pipeline] }
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
