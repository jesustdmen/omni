require "test_helper"

# PB-018 — administração de status configuráveis (Configurações) + uso nas telas.
class ConfigurableStatusesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @client = Client.create!(name: "ACME")
  end

  # --- Página de Configurações lista os status por entidade ---
  test "Configurações mostra seções de status de tarefas e projetos" do
    get settings_path
    assert_response :success
    assert_select "#status-task"
    assert_select "#status-project"
    assert_select "code", text: "in_progress"
    assert_select "code", text: "planning"
  end

  # --- CRUD ---
  test "cria um novo status de tarefa" do
    assert_difference("ConfigurableStatus.count", 1) do
      post configurable_statuses_path, params: {
        configurable_status: { entity_type: "task", key: "em_revisao", name: "Em revisão",
                               color: "#3B82F6", position: 6, active: true, final: false }
      }
    end
    s = ConfigurableStatus.find_by(entity_type: "task", key: "em_revisao")
    assert_equal "Em revisão", s.name
    assert_redirected_to settings_path(anchor: "status-task")
  end

  test "rejeita criação com key inválida (não cria)" do
    assert_no_difference("ConfigurableStatus.count") do
      post configurable_statuses_path, params: {
        configurable_status: { entity_type: "task", key: "Em Revisao", name: "X", color: "#3B82F6", position: 6 }
      }
    end
    follow_redirect!
    assert_match(/não foi possível criar/i, response.body)
  end

  test "atualiza nome/cor/posição/ativo/finalizador (key não muda)" do
    s = ConfigurableStatus.find_by(entity_type: "task", key: "todo")
    patch configurable_status_path(s), params: {
      configurable_status: { name: "A Fazer!", color: "#000000", position: 9, active: false, final: true, key: "hackeada", entity_type: "project" }
    }
    s.reload
    assert_equal "A Fazer!", s.name
    assert_equal "#000000", s.color
    assert_equal false, s.active
    assert_equal true, s.final
    assert_equal "todo", s.key, "key não deve ser editável"
    assert_equal "task", s.entity_type, "entity_type não deve mudar"
  end

  # --- Exclusão: bloqueada em uso, permitida quando livre ---
  test "não exclui status EM USO; mostra mensagem clara" do
    Task.create!(title: "T", type: "support", status: "in_progress", client: @client)
    s = ConfigurableStatus.find_by(entity_type: "task", key: "in_progress")
    assert_no_difference("ConfigurableStatus.count") do
      delete configurable_status_path(s)
    end
    follow_redirect!
    assert_match(/em uso e não pode ser exclu/i, response.body)
  end

  test "exclui status NÃO usado" do
    s = ConfigurableStatus.create!(entity_type: "task", key: "temp_xyz", name: "Temp", color: "#123456", position: 99)
    assert_difference("ConfigurableStatus.count", -1) do
      delete configurable_status_path(s)
    end
  end

  # --- Inativo: some dos selects de novo, mas registro antigo continua válido ---
  test "status inativo não aparece no select do form de nova tarefa" do
    ConfigurableStatus.find_by(entity_type: "task", key: "canceled").update!(active: false)
    get new_task_path
    assert_response :success
    assert_select "select[name='task[status]'] option[value='canceled']", count: 0
    assert_select "select[name='task[status]'] option[value='todo']" # ativo aparece
  end

  test "tarefa com status inativo continua editável e o status aparece no seu próprio select" do
    canceled = ConfigurableStatus.find_by(entity_type: "task", key: "canceled")
    task = Task.create!(title: "T", type: "support", status: "canceled", client: @client)
    canceled.update!(active: false)
    get edit_task_path(task)
    assert_response :success
    # o status atual (inativo) deve aparecer para não "sumir" o valor gravado
    assert_select "select[name='task[status]'] option[value='canceled'][selected='selected']"
  end

  # --- Labels configurados nas telas ---
  test "lista de tarefas usa o rótulo configurado no filtro e no badge" do
    Task.create!(title: "Tarefa X", type: "support", status: "in_progress", client: @client)
    get tasks_path
    assert_response :success
    # filtro de status traz o label PT-BR configurado
    assert_select "select[name='status'] option", text: "Em andamento"
    # badge mostra o label configurado
    assert_select "span.badge--config", text: "Em andamento"
  end

  test "lista de projetos usa o rótulo configurado" do
    Project.create!(name: "Proj X", status: "planning", client: @client)
    get projects_path
    assert_response :success
    assert_select "select[name='status'] option", text: "Planejamento"
    assert_select "span.badge--config", text: "Planejamento"
  end

  test "badge usa classe por status (sem style inline — CSP) e a cor vai num <style nonce>" do
    ConfigurableStatus.find_by(entity_type: "project", key: "planning").update!(color: "#3B82F6")
    Project.create!(name: "Proj cor", status: "planning", client: @client)
    get projects_path
    # badge referencia a classe do status e NÃO tem style inline (bloqueado pela CSP)
    assert_select "span.badge--config.cfg-status--project-planning"
    assert_select "span.badge--config[style]", count: 0, message: "badge não deve ter style inline (CSP)"
    # a cor é emitida num bloco <style> (com nonce) no layout
    assert_match(/\.cfg-status--project-planning\s*\{[^}]*color:\s*#3b82f6/i, response.body)
    assert_match(/background:\s*rgba\(59,130,246,0\.14\)/i, response.body)
  end

  test "renomear um status reflete na lista" do
    ConfigurableStatus.find_by(entity_type: "task", key: "in_progress").update!(name: "Tocando")
    Task.create!(title: "Tarefa Y", type: "support", status: "in_progress", client: @client)
    get tasks_path
    assert_select "span.badge--config", text: "Tocando"
  end

  # --- finalizador é só visual: não bloqueia edição nem dispara regra ---
  test "marcar finalizador não bloqueia editar a tarefa com esse status" do
    ConfigurableStatus.find_by(entity_type: "task", key: "done").update!(final: true)
    task = Task.create!(title: "Final", type: "support", status: "done", client: @client)
    patch task_path(task), params: { task: { title: "Final editado", type: "support", status: "done" } }
    assert task.reload.title == "Final editado", "finalizador não deve impedir edição"
  end

  # --- Demanda permanece fixa (não passa pelo controller; status fixo) ---
  test "Demanda mantém status fixo pending/converted (não há config de demanda)" do
    assert_equal %w[pending converted], Demand.statuses.keys
    assert_nil ConfigurableStatus.find_by(entity_type: "demand")
    d = Demand.create!(title: "D", origin: "email", priority: "low", status: "pending", client: @client)
    assert d.pending?
    assert_equal "Pendente", d.status_label
  end

  # --- Autorização ---
  test "exige autenticação para criar status" do
    sign_out @user
    post configurable_statuses_path, params: {
      configurable_status: { entity_type: "task", key: "x_novo", name: "X", color: "#111111", position: 9 }
    }
    assert_redirected_to new_user_session_path
  end

  # --- FK garante entidade certa: não é possível gravar status de project numa task ---
  test "tarefa não aceita key que só existe em projetos (integridade por entidade)" do
    # 'on_hold' existe só para project — não deve ser válido para task.
    t = Task.new(title: "T", type: "support", status: "on_hold", client: @client)
    assert_not t.valid?
    assert t.errors[:status].any?
  end
end
