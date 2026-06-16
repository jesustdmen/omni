require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
    @project = @client.projects.create!(name: "Portal")
  end

  def build_task(attrs = {})
    @client.tasks.build({ title: "T", type: "support" }.merge(attrs))
  end

  test "title obrigatório" do
    task = build_task(title: nil)
    assert_not task.valid?
    assert task.errors[:title].any?
  end

  test "client obrigatório" do
    assert_not Task.new(title: "T", type: "support").valid?
  end

  test "type obrigatório" do
    task = build_task(type: nil)
    assert_not task.valid?
    assert task.errors[:type].any?
  end

  test "type restrito à lista do RepoA" do
    assert_not build_task(type: "bogus").valid?
    Task::TYPES.each do |ty|
      assert build_task(type: ty).valid?, "#{ty} deveria ser válido"
    end
  end

  test "status default é todo" do
    task = @client.tasks.create!(title: "T", type: "support")
    assert_equal "todo", task.status
  end

  test "status aceita somente valores permitidos" do
    assert_not build_task(status: "bogus").valid?
    %w[pending todo in_progress done canceled].each do |st|
      assert build_task(status: st).valid?, "#{st} deveria ser válido"
    end
  end

  test "conversation_count default 0 e last_conversation_at nil" do
    task = @client.tasks.create!(title: "T", type: "support")
    assert_equal 0, task.conversation_count
    assert_nil task.last_conversation_at
  end

  test "project é opcional" do
    assert build_task.valid?
  end

  test "ao excluir cliente, tasks são excluídas" do
    @client.tasks.create!(title: "T", type: "support")
    assert_difference "Task.count", -1 do
      @client.destroy
    end
  end

  test "ao excluir projeto, project_id da task fica nil" do
    task = @client.tasks.create!(title: "T", type: "support", project: @project)
    @project.destroy
    assert_nil task.reload.project_id
    assert Task.exists?(task.id)
  end

  test "task não aceita projeto de outro cliente" do
    other = Client.create!(name: "Other")
    other_project = other.projects.create!(name: "X")
    task = build_task(project: other_project)
    assert_not task.valid?
    assert task.errors[:project].any?
  end

  test "type funciona como atributo comum e não ativa STI" do
    assert_equal :_type_disabled, Task.inheritance_column.to_sym
    task = @client.tasks.create!(title: "T", type: "support")
    assert_equal "support", task.type
    assert_instance_of Task, Task.find(task.id)
  end
end
