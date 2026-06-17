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
end
