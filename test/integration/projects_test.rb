require "test_helper"

class ProjectsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
  end

  test "exige autenticação" do
    sign_out @user
    get projects_path
    assert_redirected_to new_user_session_path
  end

  test "index renderiza" do
    @client.projects.create!(name: "Portal")
    get projects_path
    assert_response :success
    assert_select "h1", "Projetos"
    assert_select "td", /Portal/
  end

  test "new renderiza formulário com select de cliente" do
    get new_project_path
    assert_response :success
    assert_select "form"
    assert_select "select[name=?]", "project[client_id]"
  end

  test "create válido redireciona" do
    assert_difference "Project.count", 1 do
      post projects_path, params: { project: { client_id: @client.id, name: "Portal", status: "planning" } }
    end
    assert_response :redirect
  end

  test "create inválido mostra erro" do
    assert_no_difference "Project.count" do
      post projects_path, params: { project: { client_id: @client.id, name: "" } }
    end
    assert_response :unprocessable_entity
    assert_select "div.errors"
  end

  test "show mostra dados principais" do
    project = @client.projects.create!(name: "Portal")
    get project_path(project)
    assert_response :success
    assert_select "h1", "Portal"
    assert_select "dd", /ACME/
  end

  test "edit e update" do
    project = @client.projects.create!(name: "Portal")
    get edit_project_path(project)
    assert_response :success
    patch project_path(project), params: { project: { name: "Portal 2" } }
    assert_redirected_to project_path(project)
    assert_equal "Portal 2", project.reload.name
  end

  test "destroy" do
    project = @client.projects.create!(name: "Portal")
    assert_difference "Project.count", -1 do
      delete project_path(project)
    end
    assert_redirected_to projects_path
  end
end
