require "test_helper"

# PB-016a — disparo agendado da sincronização (sem Tarefa do Windows).
class ScheduledSyncJobTest < ActiveJob::TestCase
  test "não dispara quando o agendamento está desativado" do
    SyncSchedule.current.update!(enabled: false)
    assert_no_difference "SyncExecution.count" do
      assert_no_enqueued_jobs(only: SyncConversationsJob) { ScheduledSyncJob.perform_now }
    end
  end

  test "dispara quando habilitado e vencido (sem last_enqueued_at)" do
    SyncSchedule.current.update!(enabled: true, interval_minutes: 60, last_enqueued_at: nil)
    assert_difference "SyncExecution.count", 1 do
      assert_enqueued_with(job: SyncConversationsJob) { ScheduledSyncJob.perform_now }
    end
    exec = SyncExecution.order(:created_at).last
    assert_equal "scheduled", exec.trigger
    assert_not_nil SyncSchedule.current.last_enqueued_at
  end

  test "NÃO dispara antes de vencer o intervalo" do
    SyncSchedule.current.update!(enabled: true, interval_minutes: 60, last_enqueued_at: 10.minutes.ago)
    assert_no_difference "SyncExecution.count" do
      ScheduledSyncJob.perform_now
    end
  end

  test "dispara de novo após o intervalo vencer" do
    SyncSchedule.current.update!(enabled: true, interval_minutes: 30, last_enqueued_at: 31.minutes.ago)
    assert_difference "SyncExecution.count", 1 do
      ScheduledSyncJob.perform_now
    end
  end

  test "não dispara se já há execução ativa" do
    SyncSchedule.current.update!(enabled: true, interval_minutes: 60, last_enqueued_at: nil)
    SyncExecution.create!(status: "running", trigger: "manual")
    assert_no_difference "SyncExecution.count" do
      ScheduledSyncJob.perform_now
    end
  end

  test "SyncSchedule é singleton (current reaproveita a mesma linha)" do
    a = SyncSchedule.current
    b = SyncSchedule.current
    assert_equal a.id, b.id
    assert_equal 1, SyncSchedule.count
  end

  test "due? respeita enabled e intervalo" do
    s = SyncSchedule.new(enabled: false, interval_minutes: 60)
    assert_not s.due?
    s.enabled = true
    s.last_enqueued_at = nil
    assert s.due?
    s.last_enqueued_at = 5.minutes.ago
    assert_not s.due?(now: Time.current)
    s.last_enqueued_at = 61.minutes.ago
    assert s.due?
  end
end
