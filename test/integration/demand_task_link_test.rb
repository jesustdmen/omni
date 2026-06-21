require "test_helper"

# PB-004c — fluxo demanda↔tarefa via UI/controllers + concorrência + regressão.
class DemandTaskLinkTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
  end

  def pending_demand(attrs = {})
    Demand.create!({ title: "Bug X", description: "detalhe", origin: "email", priority: "high", client: @client }.merge(attrs))
  end

  # --- conversão / concorrência -------------------------------------------

  test "converter via UI vincula e redireciona para a tarefa" do
    d = pending_demand
    assert_difference "Task.count", 1 do
      post convert_demand_path(d)
    end
    task = Task.order(:created_at).last
    assert_equal d.id, task.demand_id
    assert_redirected_to task_path(task)
  end

  test "concorrência: duas conversões não geram duas tarefas" do
    d = pending_demand
    # 1ª conversão real
    assert ConvertDemand.call(d).success?
    # 2ª (simula corrida pós-commit): revalidação pós-lock barra
    assert_no_difference "Task.count" do
      assert_not ConvertDemand.call(d.reload).success?
    end
    assert_equal 1, Task.where(demand_id: d.id).count
  end

  # --- exclusão da tarefa (controller usa DeleteTask) ----------------------

  test "excluir tarefa via controller devolve a demanda para pending (mensagem clara)" do
    d = pending_demand
    task = ConvertDemand.call(d).task
    delete task_path(task)
    assert_redirected_to tasks_path
    follow_redirect!
    assert_select ".flash--notice", /demanda de origem voltou para pendente/i
    assert d.reload.pending?
    assert_nil d.converted_at
  end

  test "excluir tarefa sem demanda via controller funciona normalmente" do
    task = @client.tasks.create!(title: "avulsa", type: "support", status: "todo")
    assert_difference "Task.count", -1 do
      delete task_path(task)
    end
    assert_redirected_to tasks_path
  end

  # --- exclusão da demanda -------------------------------------------------

  test "excluir demanda vinculada é bloqueado com mensagem amigável" do
    d = pending_demand
    ConvertDemand.call(d)
    assert_no_difference "Demand.count" do
      delete demand_path(d)
    end
    assert_redirected_to demand_path(d)
    follow_redirect!
    assert_select ".flash--alert", /gerou uma tarefa e não pode ser excluída/i
  end

  test "excluir demanda pending sem vínculo funciona" do
    d = pending_demand
    assert_difference "Demand.count", -1 do
      delete demand_path(d)
    end
    assert_redirected_to demands_path
  end

  # --- UI ------------------------------------------------------------------

  test "UI da tarefa: aba Demanda mostra a origem quando há vínculo" do
    d = pending_demand
    task = ConvertDemand.call(d).task
    get task_path(task)
    assert_response :success
    assert_select "#tab-demanda h2", "Demanda de origem"
    assert_select "#tab-demanda dd a[href=?]", demand_path(d), /Bug X/
    assert_select "#tab-demanda a[href=?]", demand_path(d), /Abrir demanda/
    assert_select "a.tab[href=?]", "#tab-demanda", /Demanda/
  end

  test "UI da tarefa: aba Demanda mostra estado vazio honesto quando não há vínculo" do
    task = @client.tasks.create!(title: "avulsa", type: "support", status: "todo")
    get task_path(task)
    assert_select "#tab-demanda", /não foi criada a partir de uma demanda/i
  end

  test "UI da demanda: convertida mostra link para a tarefa e não oferece nova conversão" do
    d = pending_demand
    task = ConvertDemand.call(d).task
    get demand_path(d)
    assert_response :success
    assert_select ".converted-state a[href=?]", task_path(task), /Abrir tarefa/
    assert_select "form[action=?]", convert_demand_path(d), count: 0 # sem botão converter
  end

  test "UI da demanda: pending mostra botão converter" do
    d = pending_demand
    get demand_path(d)
    assert_select "form[action=?]", convert_demand_path(d)
  end

  # --- auth ----------------------------------------------------------------

  test "exige autenticação para converter" do
    sign_out @user
    d = pending_demand
    assert_no_difference "Task.count" do
      post convert_demand_path(d)
    end
    assert_redirected_to new_user_session_path
  end

  # --- regressão -----------------------------------------------------------

  test "regressão: página da tarefa segue com checklist, conversas e apontamentos" do
    d = pending_demand
    task = ConvertDemand.call(d).task
    task.checklist_items.create!(content: "item")
    t = Time.current
    task.time_entries.create!(start_time: t, end_time: t + 600.seconds)
    get task_path(task)
    assert_response :success
    assert_select ".checklist"
    assert_select "#tab-conversas"
    assert_select "#tab-time", /Histórico de Apontamentos/
    assert_select "#tab-demanda", /Demanda de origem/
  end
end
