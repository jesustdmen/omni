require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "T", type: "support")
  end

  def build_entry(attrs = {})
    @task.time_entries.build({ start_time: Time.current, date: Date.current, duration: 0 }.merge(attrs))
  end

  test "task obrigatório" do
    entry = TimeEntry.new(start_time: Time.current, date: Date.current)
    assert_not entry.valid?
    assert entry.errors[:task].any?
  end

  test "start_time obrigatório" do
    assert_not build_entry(start_time: nil).valid?
  end

  test "date obrigatório" do
    assert_not build_entry(date: nil).valid?
  end

  test "duration deve ser >= 0" do
    assert_not build_entry(duration: -1).valid?
    assert build_entry(duration: 0).valid?
    assert build_entry(duration: 120).valid?
  end

  test "duration default 0" do
    entry = @task.time_entries.create!(start_time: Time.current, date: Date.current)
    assert_equal 0, entry.duration
  end

  test "is_running default false" do
    entry = @task.time_entries.create!(start_time: Time.current, date: Date.current)
    assert_equal false, entry.is_running
  end

  test "end_time é opcional" do
    assert build_entry(end_time: nil).valid?
  end

  test "end_time não pode ser anterior ao start_time" do
    t = Time.current
    assert_not build_entry(start_time: t, end_time: t - 1.hour).valid?
    assert build_entry(start_time: t, end_time: t + 1.hour).valid?
  end

  test "conversation_id existe como coluna e permanece nil" do
    entry = @task.time_entries.create!(start_time: Time.current, date: Date.current)
    assert_includes TimeEntry.column_names, "conversation_id"
    assert_nil entry.conversation_id
  end

  test "ao excluir a task, os time_entries são excluídos (cascade)" do
    @task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 10)
    assert_difference "TimeEntry.count", -1 do
      @task.destroy
    end
  end

  test "Task#total_duration soma as durações dos apontamentos" do
    @task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 30)
    @task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 12)
    assert_equal 42, @task.reload.total_duration
  end

  # --- PB-003a — timer ---

  test "scope running retorna só timers abertos" do
    open = TimeEntry.start_for(@task)
    closed = @task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 60)
    assert_includes TimeEntry.running, open
    assert_not_includes TimeEntry.running, closed
  end

  test "start_for cria timer running sem end_time" do
    entry = TimeEntry.start_for(@task)
    assert entry.persisted?
    assert entry.is_running
    assert_nil entry.end_time
    assert_equal 0, entry.duration
  end

  test "stop! calcula duração em segundos e encerra" do
    start = Time.current - 90.seconds
    entry = @task.time_entries.create!(start_time: start, date: start.to_date, is_running: true, duration: 0)
    entry.stop!(at: start + 90.seconds)
    assert_not entry.is_running
    assert_not_nil entry.end_time
    assert_equal 90, entry.duration
  end

  test "não permite dois timers abertos na mesma tarefa" do
    TimeEntry.start_for(@task)
    dup = TimeEntry.start_for(@task)
    assert_not dup.persisted?
    assert dup.errors[:base].any?
  end

  test "com paralelismo permitido, timers em tarefas diferentes coexistem" do
    other = @client.tasks.create!(title: "T2", type: "support")
    a = TimeEntry.start_for(@task)
    b = TimeEntry.start_for(other)
    assert a.persisted?
    assert b.persisted?, "timer em outra tarefa deve ser permitido com paralelismo ligado"
  end

  test "com paralelismo desabilitado, bloqueia novo timer havendo qualquer aberto" do
    other = @client.tasks.create!(title: "T2", type: "support")
    TimeEntry.start_for(@task)
    with_parallel_timers(false) do
      blocked = TimeEntry.start_for(other)
      assert_not blocked.persisted?
      assert blocked.errors[:base].any?
    end
  end

  private

  def with_parallel_timers(value)
    prev = Rails.configuration.x.allow_parallel_running_timers
    Rails.configuration.x.allow_parallel_running_timers = value
    yield
  ensure
    Rails.configuration.x.allow_parallel_running_timers = prev
  end
end
