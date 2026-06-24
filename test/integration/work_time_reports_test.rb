require "test_helper"

# PB-020a — tela de Apuração de horas (read-only; PT-BR; sem valor/contrato).
class WorkTimeReportsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "Tarefa Apurada", type: "support")
  end

  def entry(date, secs)
    start_t = Time.zone.local(date.year, date.month, date.day, 9, 0, 0)
    TimeEntry.create!(task: @task, start_time: start_t, end_time: start_t + secs, is_running: false)
  end

  test "exige autenticação" do
    sign_out @user
    get work_time_reports_path
    assert_redirected_to new_user_session_path
  end

  test "sidebar tem item Apuração (grupo Comercial)" do
    get root_path
    assert_select "a[href=?]", work_time_reports_path, text: /Apuração/
  end

  test "renderiza a tela em PT-BR com título e filtros" do
    entry(Date.new(2026, 6, 10), 3600) # garante a tabela (cabeçalhos das colunas)
    get work_time_reports_path(start_date: "2026-06-01", end_date: "2026-06-30")
    assert_response :success
    assert_select "h1", "Apuração de horas"
    assert_select "input[name=start_date]"
    assert_select "input[name=end_date]"
    assert_select "select[name=client_id]"
    assert_match "Horas apuradas", response.body
    assert_match "Conversas vinculadas", response.body
  end

  test "lista tarefa com horas no período e total" do
    entry(Date.new(2026, 6, 10), 3600)
    get work_time_reports_path(start_date: "2026-06-01", end_date: "2026-06-30")
    assert_response :success
    assert_match "Tarefa Apurada", response.body
    assert_match "1 h", response.body # duration_label de 3600s
  end

  test "tarefa sem horas mas com conversa aparece como 'Sem horas lançadas' quando incluída" do
    @task.update_columns(conversation_count: 1)
    get work_time_reports_path(start_date: "2026-06-01", end_date: "2026-06-30", include_without_hours: "true")
    assert_response :success
    assert_match "Sem horas lançadas", response.body
  end

  test "estado vazio quando não há horas no período" do
    get work_time_reports_path(start_date: "2020-01-01", end_date: "2020-01-31")
    assert_select ".empty"
  end

  test "não exibe valor monetário nem contrato no conteúdo (escopo negativo)" do
    entry(Date.new(2026, 6, 10), 3600)
    get work_time_reports_path(start_date: "2026-06-01", end_date: "2026-06-30")
    # Avalia só o conteúdo principal (a sidebar tem o item "Contratos", fora de escopo).
    main = css_select("main.app-main").to_s
    refute_empty main
    # "sem valor" (PT-BR, intencional) é permitido; valor MONETÁRIO/contrato não.
    refute_match(/R\$/, main)
    refute_match(/valor\/hora|valor estimado|valor calculado|valor apurado/i, main)
    refute_match(/contrato/i, main)
    refute_match(/billing|preview|unpriced/i, main)
  end

  test "default de período é o mês atual (Brasília) quando sem params" do
    get work_time_reports_path
    today = Time.zone.today
    assert_select "input[name=start_date][value=?]", today.beginning_of_month.iso8601
    assert_select "input[name=end_date][value=?]", today.end_of_month.iso8601
  end
end
