require "test_helper"

class TimeEntriesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "Bug X", type: "support")
  end

  # PB-003c — apontamento retroativo válido: início + término (date/duration derivados).
  def entry_params(attrs = {})
    { task_id: @task.id, start_time: "2026-06-17T09:00", end_time: "2026-06-17T09:30", description: "x" }.merge(attrs)
  end

  # apontamento parado válido (início+término) criado direto via model.
  def stopped_entry(at: Time.current, secs: 1800, task: @task)
    task.time_entries.create!(start_time: at, end_time: at + secs)
  end

  test "exige autenticação" do
    sign_out @user
    get time_entries_path
    assert_redirected_to new_user_session_path
  end

  test "index renderiza" do
    stopped_entry
    get time_entries_path
    assert_response :success
    assert_select "h1", "Time entries"
    assert_select "td", /Bug X/
  end

  # --- PB-003c — formulário retroativo ---

  test "new é retroativo: tem início/término; NÃO tem date/duration/is_running" do
    get new_time_entry_path
    assert_response :success
    assert_select "h1", "Novo apontamento retroativo"
    assert_select "select[name=?]", "time_entry[task_id]"
    assert_select "input[name=?]", "time_entry[start_time]"
    assert_select "input[name=?]", "time_entry[end_time]"
    assert_select "input[name=?]", "time_entry[duration]", count: 0
    assert_select "input[name=?]", "time_entry[date]", count: 0
    assert_select "input[name=?]", "time_entry[is_running]", count: 0
  end

  test "new pré-preenche início (default) e pré-seleciona task via parâmetro" do
    get new_time_entry_path(task_id: @task.id)
    assert_response :success
    assert_select "option[selected][value=?]", @task.id
    assert_select "input[name='time_entry[start_time]'][value]" # início preenchido
  end

  test "create retroativo calcula duration em segundos e deriva date" do
    assert_difference "TimeEntry.count", 1 do
      post time_entries_path, params: { time_entry: entry_params }
    end
    e = TimeEntry.order(:created_at).last
    assert_response :redirect
    assert_equal 1800, e.duration            # 09:00→09:30 = 1800 s
    assert_equal Date.new(2026, 6, 17), e.date
    assert_not e.is_running
  end

  test "end_time obrigatório para não running" do
    assert_no_difference "TimeEntry.count" do
      post time_entries_path, params: { time_entry: entry_params(end_time: "") }
    end
    assert_response :unprocessable_entity
    assert_select "div.errors"
  end

  test "end_time anterior ao início é bloqueado" do
    assert_no_difference "TimeEntry.count" do
      post time_entries_path, params: { time_entry: entry_params(end_time: "2026-06-17T08:00") }
    end
    assert_response :unprocessable_entity
  end

  test "duration/date/is_running enviados por params são ignorados" do
    post time_entries_path, params: {
      time_entry: entry_params(duration: 9999, date: "2000-01-01", is_running: "1")
    }
    e = TimeEntry.order(:created_at).last
    assert_equal 1800, e.duration                 # derivado, não 9999
    assert_equal Date.new(2026, 6, 17), e.date     # derivado, não 2000-01-01
    assert_not e.is_running                         # is_running não atribuível por form
  end

  test "conversation_id não é atribuível via params" do
    cid = SecureRandom.uuid
    post time_entries_path, params: { time_entry: entry_params.merge(conversation_id: cid) }
    assert_equal 0, TimeEntry.where(conversation_id: cid).count
    assert_nil TimeEntry.order(:created_at).last&.conversation_id
  end

  test "show" do
    get time_entry_path(stopped_entry)
    assert_response :success
    assert_select "dd", /Bug X/
  end

  test "edit retroativo recalcula duration/date a partir de início/término" do
    entry = stopped_entry
    patch time_entry_path(entry), params: {
      time_entry: { start_time: "2026-06-18T10:00", end_time: "2026-06-18T10:45" }
    }
    assert_redirected_to time_entry_path(entry)
    entry.reload
    assert_equal 2700, entry.duration              # 45 min
    assert_equal Date.new(2026, 6, 18), entry.date
  end

  test "edição de running: só descrição muda; tarefa e todos os campos temporais ficam intactos" do
    other = @client.tasks.create!(title: "Outra", type: "support")
    start = Time.zone.local(2026, 6, 17, 8, 0)
    running = @task.time_entries.create!(start_time: start, date: Date.new(2026, 6, 17), is_running: true, duration: 0)

    patch time_entry_path(running), params: {
      time_entry: {
        task_id: other.id,                  # tentativa de trocar a tarefa
        start_time: "2000-01-01T00:00",     # tentativa de mexer no início
        end_time: "2000-01-01T01:00",       # tentativa de fechar o timer
        date: "2000-01-01",                 # tentativa de mexer na data
        duration: 9999,                     # tentativa de injetar duração
        is_running: "0",                    # tentativa de parar via form
        description: "nota nova"            # único campo legítimo
      }
    }
    running.reload
    assert_equal "nota nova", running.description   # único alterado
    assert_equal @task.id, running.task_id          # tarefa intacta
    assert_equal start, running.start_time          # início intacto
    assert_nil running.end_time                     # término intacto
    assert_equal start.to_date, running.date        # data intacta
    assert_equal 0, running.duration                # duração intacta
    assert running.is_running                        # segue em andamento
  end

  test "destroy" do
    entry = stopped_entry
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
    assert entry.duration >= 110
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

  # --- PB-003c — lista de timers em andamento ---

  test "running lista somente timers em andamento com tarefa/cliente/ações" do
    TimeEntry.start_for(@task)
    stopped_entry # parado, não deve aparecer
    get running_time_entries_path
    assert_response :success
    assert_select "h1", "Timers em andamento"
    assert_select "td", /Bug X/      # tarefa
    assert_select "td", /ACME/       # cliente
    assert_select "form[action=?]", stop_time_entry_path(TimeEntry.running.first) # ação Parar
    assert_select "a[href=?]", task_path(@task) # abrir tarefa
    assert_select "table tbody tr", 1 # só o running
  end

  test "running exige autenticação" do
    sign_out @user
    get running_time_entries_path
    assert_redirected_to new_user_session_path
  end

  test "running não faz N+1: time_entries em consulta única (independe de nº de timers)" do
    3.times do |i|
      t = @client.tasks.create!(title: "P#{i}", type: "support")
      TimeEntry.start_for(t)
    end
    q = count_queries(/FROM "time_entries"/) { get running_time_entries_path }
    assert_response :success
    assert q <= 2, "esperava ≤2 queries em time_entries (lista + count do banner), obteve #{q}"
  end

  test "running mostra nota de sobreposição" do
    TimeEntry.start_for(@task)
    get running_time_entries_path
    assert_select ".te-overlap-note", /tempo lançado/
  end

  # --- PB-003c — aviso global de timers na topbar ---

  test "aviso global aparece quando há timer em andamento" do
    TimeEntry.start_for(@task)
    get time_entries_path
    assert_select ".topbar__timers", /em andamento/
    assert_select "a.topbar__timers[href=?]", running_time_entries_path
  end

  test "aviso global ausente quando não há timer" do
    get time_entries_path
    assert_select ".topbar__timers", count: 0
  end

  private

  def with_parallel_timers(value)
    prev = Rails.configuration.x.allow_parallel_running_timers
    Rails.configuration.x.allow_parallel_running_timers = value
    yield
  ensure
    Rails.configuration.x.allow_parallel_running_timers = prev
  end

  def count_queries(pattern)
    count = 0
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      count += 1 if pattern.match?(args.last[:sql].to_s)
    end
    yield
    ActiveSupport::Notifications.unsubscribe(sub)
    count
  end
end
