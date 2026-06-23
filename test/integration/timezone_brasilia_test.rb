require "test_helper"

# Timezone operacional = Brasília; banco persiste em UTC (ADR-023).
# Cobre apontamentos/timers/derivação de date/agrupamento/exibição.
class TimezoneBrasiliaTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "Bug X", type: "support")
  end

  # --- configuração ---------------------------------------------------------

  test "Time.zone é Brasília e o banco persiste em UTC" do
    assert_equal "Brasilia", Time.zone.name
    assert_equal "America/Sao_Paulo", Time.zone.tzinfo.name
    assert_equal :utc, ActiveRecord.default_timezone
    assert_equal(-3 * 3600, Time.zone.now.utc_offset)
  end

  # --- create retroativo (parse em Brasília) --------------------------------

  test "create retroativo 09:00→09:30 BR: duration 1800, date 2026-06-17, UTC +3h no banco" do
    assert_difference "TimeEntry.count", 1 do
      post time_entries_path, params: { time_entry: {
        task_id: @task.id, start_time: "2026-06-17T09:00", end_time: "2026-06-17T09:30", description: "x"
      } }
    end
    e = TimeEntry.order(:created_at).last
    assert_equal 1800, e.duration
    assert_equal Date.new(2026, 6, 17), e.date
    # interpretado como 09:00 Brasília → 12:00 UTC no banco
    assert_equal "2026-06-17 12:00:00 UTC", e.start_time.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
    assert_equal "2026-06-17 12:30:00 UTC", e.end_time.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
    # exibido em Brasília (09:00 / 09:30)
    assert_equal "17/06/2026 09:00", e.start_time.in_time_zone.strftime("%d/%m/%Y %H:%M")
    assert_equal "17/06/2026 09:30", e.end_time.in_time_zone.strftime("%d/%m/%Y %H:%M")
  end

  test "create retroativo: a UI mostra 09:00 e 09:30 (Brasília)" do
    post time_entries_path, params: { time_entry: {
      task_id: @task.id, start_time: "2026-06-17T09:00", end_time: "2026-06-17T09:30", description: "y"
    } }
    e = TimeEntry.order(:created_at).last
    get time_entry_path(e)
    assert_response :success
    assert_select "dd", /17\/06\/2026 09:00/
    assert_select "dd", /17\/06\/2026 09:30/
  end

  # --- fronteira (meia-noite) -----------------------------------------------

  test "fronteira 00:30 BR: date é 2026-06-17 (não o dia anterior em UTC)" do
    post time_entries_path, params: { time_entry: {
      task_id: @task.id, start_time: "2026-06-17T00:30", end_time: "2026-06-17T01:00", description: "z"
    } }
    e = TimeEntry.order(:created_at).last
    assert_equal Date.new(2026, 6, 17), e.date
    # no banco, 00:30 BR = 03:30 UTC do MESMO dia
    assert_equal "2026-06-17 03:30:00 UTC", e.start_time.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
  end

  test "fronteira inversa 22:00 BR: date é o dia BR, não o dia seguinte em UTC" do
    # 22:00 BR = 01:00 UTC do dia seguinte; date deve ser o dia de Brasília.
    post time_entries_path, params: { time_entry: {
      task_id: @task.id, start_time: "2026-06-17T22:00", end_time: "2026-06-17T22:30", description: "w"
    } }
    e = TimeEntry.order(:created_at).last
    assert_equal Date.new(2026, 6, 17), e.date
    assert_equal "2026-06-18 01:00:00 UTC", e.start_time.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
  end

  # --- timer start/stop ------------------------------------------------------

  test "start_for deriva date em Brasília (fronteira)" do
    at = Time.utc(2026, 6, 18, 1, 0) # 01:00 UTC = 22:00 BR do dia 17
    e = TimeEntry.start_for(@task, at: at)
    assert e.persisted?, e.errors.full_messages.to_sentence
    assert e.is_running
    assert_equal Date.new(2026, 6, 17), e.date # dia de Brasília
  end

  test "stop! mantém duração correta (instantes; independe de tz)" do
    at = Time.current
    e = TimeEntry.start_for(@task, at: at)
    e.stop!(at: at + 1800)
    assert_not e.is_running
    assert_equal 1800, e.duration
  end

  # --- histórico agrupado por dia (Brasília) --------------------------------

  test "histórico por tarefa agrupa pelo dia de Brasília" do
    # 22:00 BR (01:00 UTC do dia seguinte) e 09:00 BR do mesmo dia 17 → MESMO grupo (17/06).
    @task.time_entries.create!(start_time: Time.zone.parse("2026-06-17T09:00"), end_time: Time.zone.parse("2026-06-17T09:30"))
    @task.time_entries.create!(start_time: Time.zone.parse("2026-06-17T22:00"), end_time: Time.zone.parse("2026-06-17T22:30"))
    get task_path(@task)
    assert_response :success
    # um único cabeçalho de dia 17/06/2026 (ambas no dia BR)
    assert_select ".te-day__head th", /17\/06\/2026/
    assert_select ".te-day__head", 1
  end
end
