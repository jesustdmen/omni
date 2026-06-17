require "test_helper"

class TasksTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
    @project = @client.projects.create!(name: "Portal")
  end

  test "exige autenticação" do
    sign_out @user
    get tasks_path
    assert_redirected_to new_user_session_path
  end

  test "index renderiza" do
    @client.tasks.create!(title: "Bug X", type: "support")
    get tasks_path
    assert_response :success
    assert_select "h1", "Tarefas"
    assert_select "td", /Bug X/
  end

  test "new renderiza formulário com selects" do
    get new_task_path
    assert_response :success
    assert_select "form"
    assert_select "select[name=?]", "task[client_id]"
    assert_select "select[name=?]", "task[project_id]"
    assert_select "select[name=?]", "task[type]"
    assert_select "select[name=?]", "task[status]"
  end

  test "create válido redireciona" do
    assert_difference "Task.count", 1 do
      post tasks_path, params: { task: { client_id: @client.id, title: "Bug X", type: "support", status: "todo" } }
    end
    assert_response :redirect
  end

  test "create inválido mostra erro" do
    assert_no_difference "Task.count" do
      post tasks_path, params: { task: { client_id: @client.id, title: "", type: "support" } }
    end
    assert_response :unprocessable_entity
    assert_select "div.errors"
  end

  test "show /tasks/:id mostra dados e abas" do
    task = @client.tasks.create!(title: "Bug X", type: "support", project: @project)
    get task_path(task)
    assert_response :success
    assert_select "h1", "Bug X"
    assert_select "dd", /ACME/
    assert_select "dd", /Portal/
    assert_select ".tab", /Detalhes/
    assert_select ".tab", /Conversas/
    assert_select ".tab", /Time entries/
    assert_select ".tab", /Histórico/
    assert_select ".tab", /Demanda/
  end

  test "aba Time entries mostra lista read-only e total de duração" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 30)
    task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 12)
    get task_path(task)
    assert_response :success
    assert_select "#tab-time table"
    assert_select "#tab-time", /Total de duração/
    assert_select "#tab-time", /42/
  end

  test "edit e update" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    get edit_task_path(task)
    assert_response :success
    patch task_path(task), params: { task: { title: "Bug Y" } }
    assert_redirected_to task_path(task)
    assert_equal "Bug Y", task.reload.title
  end

  test "destroy" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    assert_difference "Task.count", -1 do
      delete task_path(task)
    end
    assert_redirected_to tasks_path
  end
end
