require "test_helper"

class TimeEntriesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "Bug X", type: "support")
  end

  def entry_params(attrs = {})
    { task_id: @task.id, start_time: "2026-06-17T09:00", date: "2026-06-17", duration: 30, is_running: "0" }.merge(attrs)
  end

  test "exige autenticação" do
    sign_out @user
    get time_entries_path
    assert_redirected_to new_user_session_path
  end

  test "index renderiza" do
    @task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 30)
    get time_entries_path
    assert_response :success
    assert_select "h1", "Time entries"
    assert_select "td", /Bug X/
  end

  test "new renderiza formulário com selects/inputs" do
    get new_time_entry_path
    assert_response :success
    assert_select "form"
    assert_select "select[name=?]", "time_entry[task_id]"
    assert_select "input[name=?]", "time_entry[duration]"
    assert_select "input[name=?]", "time_entry[date]"
    assert_select "input[name=?]", "time_entry[start_time]"
  end

  test "new pré-seleciona a task via parâmetro" do
    get new_time_entry_path(task_id: @task.id)
    assert_response :success
    assert_select "option[selected][value=?]", @task.id
  end

  test "create válido" do
    assert_difference "TimeEntry.count", 1 do
      post time_entries_path, params: { time_entry: entry_params }
    end
    assert_response :redirect
  end

  test "create inválido mostra erro" do
    assert_no_difference "TimeEntry.count" do
      post time_entries_path, params: { time_entry: entry_params(start_time: "", date: "") }
    end
    assert_response :unprocessable_entity
    assert_select "div.errors"
  end

  test "conversation_id não é atribuível via params" do
    cid = SecureRandom.uuid
    post time_entries_path, params: { time_entry: entry_params.merge(conversation_id: cid) }
    # Robustez: independente de o Rails logar ou rejeitar parâmetros não
    # permitidos, conversation_id nunca é persistido a partir de params.
    assert_equal 0, TimeEntry.where(conversation_id: cid).count
    assert_nil TimeEntry.order(:created_at).last&.conversation_id
  end

  test "show" do
    entry = @task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 30)
    get time_entry_path(entry)
    assert_response :success
    assert_select "dd", /Bug X/
  end

  test "edit e update" do
    entry = @task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 30)
    get edit_time_entry_path(entry)
    assert_response :success
    patch time_entry_path(entry), params: { time_entry: entry_params(duration: 45) }
    assert_redirected_to time_entry_path(entry)
    assert_equal 45, entry.reload.duration
  end

  test "destroy" do
    entry = @task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 30)
    assert_difference "TimeEntry.count", -1 do
      delete time_entry_path(entry)
    end
    assert_redirected_to time_entries_path
  end

  # --- PB-003a — timer start/stop ---

  test "iniciar timer cria TimeEntry running" do
    assert_difference "TimeEntry.count", 1 do
      post task_timer_path(@task)
    end
    entry = TimeEntry.order(:created_at).last
    assert entry.is_running
    assert_nil entry.end_time
    assert_redirected_to task_path(@task)
  end

  test "parar timer calcula duração e encerra" do
    start = Time.current - 120.seconds
    entry = @task.time_entries.create!(start_time: start, date: start.to_date, is_running: true, duration: 0)
    patch stop_time_entry_path(entry)
    entry.reload
    assert_not entry.is_running
    assert entry.duration >= 110 # ~120s, tolerância de relógio
  end

  test "segundo timer na mesma tarefa falha" do
    post task_timer_path(@task)
    assert_no_difference "TimeEntry.count" do
      post task_timer_path(@task)
    end
    assert_redirected_to task_path(@task)
  end

  test "timer em outra tarefa é permitido com paralelismo ligado (default)" do
    other = @client.tasks.create!(title: "T2", type: "support")
    post task_timer_path(@task)
    assert_difference "TimeEntry.count", 1 do
      post task_timer_path(other)
    end
  end

  test "timer em outra tarefa é bloqueado com paralelismo desligado" do
    other = @client.tasks.create!(title: "T2", type: "support")
    post task_timer_path(@task)
    with_parallel_timers(false) do
      assert_no_difference "TimeEntry.count" do
        post task_timer_path(other)
      end
    end
  end

  test "anônimo não acessa start/stop" do
    entry = @task.time_entries.create!(start_time: Time.current, date: Date.current, is_running: true, duration: 0)
    sign_out @user
    post task_timer_path(@task)
    assert_redirected_to new_user_session_path
    patch stop_time_entry_path(entry)
    assert_redirected_to new_user_session_path
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
