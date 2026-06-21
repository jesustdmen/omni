require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "T", type: "support")
  end

  # PB-003c — apontamento retroativo VÁLIDO por padrão (não running): início+término.
  # `date`/`duration` são derivados pelo model (não informados).
  def build_entry(attrs = {})
    t = Time.current
    @task.time_entries.build({ start_time: t, end_time: t + 30.minutes }.merge(attrs))
  end

  test "task obrigatório" do
    entry = TimeEntry.new(start_time: Time.current, end_time: Time.current + 1.hour)
    assert_not entry.valid?
    assert entry.errors[:task].any?
  end

  test "start_time obrigatório" do
    assert_not build_entry(start_time: nil).valid?
  end

  test "PB-003c — apontamento não running exige end_time" do
    assert_not build_entry(end_time: nil).valid?
    assert build_entry.valid?
  end

  test "PB-003c — date é derivada de start_time (ignora date informada)" do
    t = Time.zone.local(2026, 6, 1, 9, 0)
    entry = @task.time_entries.create!(start_time: t, end_time: t + 1.hour, date: Date.new(2000, 1, 1))
    assert_equal t.to_date, entry.date
  end

  test "PB-003c — duration é derivada de início/término em segundos (ignora duration informada)" do
    t = Time.zone.local(2026, 6, 1, 9, 0)
    entry = @task.time_entries.create!(start_time: t, end_time: t + 90.seconds, duration: 9999)
    assert_equal 90, entry.duration
  end

  test "is_running default false" do
    entry = build_entry
    entry.save!
    assert_equal false, entry.is_running
  end

  test "end_time não pode ser anterior ao start_time" do
    t = Time.current
    assert_not build_entry(start_time: t, end_time: t - 1.hour).valid?
    assert build_entry(start_time: t, end_time: t + 1.hour).valid?
  end

  test "PB-003c — running não pode ter end_time" do
    entry = @task.time_entries.build(start_time: Time.current, is_running: true, end_time: Time.current + 1.hour)
    assert_not entry.valid?
    assert entry.errors[:end_time].any?
  end

  test "PB-003c — running com date divergente é normalizado para start_time.to_date" do
    start = Time.zone.local(2026, 6, 17, 8, 0)
    entry = @task.time_entries.create!(start_time: start, date: Date.new(2000, 1, 1), is_running: true, duration: 0)
    assert_equal start.to_date, entry.date
  end

  test "PB-003c — running com duration > 0 é inválido" do
    entry = @task.time_entries.build(start_time: Time.current, date: Date.current, is_running: true, duration: 5)
    assert_not entry.valid?
    assert entry.errors[:duration].any?
  end

  test "PB-003c — start_for gera date correta e duration 0" do
    at = Time.zone.local(2026, 6, 17, 8, 0)
    entry = TimeEntry.start_for(@task, at: at)
    assert entry.persisted?
    assert_equal at.to_date, entry.date
    assert_equal 0, entry.duration
  end

  test "conversation_id existe como coluna e permanece nil" do
    entry = build_entry
    entry.save!
    assert_includes TimeEntry.column_names, "conversation_id"
    assert_nil entry.conversation_id
  end

  test "ao excluir a task, os time_entries são excluídos (cascade)" do
    build_entry.save!
    assert_difference "TimeEntry.count", -1 do
      @task.destroy
    end
  end

  test "Task#total_duration soma as durações dos apontamentos" do
    t = Time.current
    @task.time_entries.create!(start_time: t, end_time: t + 30.seconds)
    @task.time_entries.create!(start_time: t, end_time: t + 12.seconds)
    assert_equal 42, @task.reload.total_duration
  end

  # --- PB-003a — timer ---

  test "scope running retorna só timers abertos" do
    open = TimeEntry.start_for(@task)
    closed = build_entry
    closed.save!
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
