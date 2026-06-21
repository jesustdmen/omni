require "test_helper"

class ChecklistItemTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "T", type: "support")
  end

  test "task obrigatória" do
    it = ChecklistItem.new(content: "x")
    assert_not it.valid?
    assert it.errors[:task].any?
  end

  test "content obrigatório" do
    assert_not @task.checklist_items.new(content: "").valid?
  end

  test "content com só espaços é inválido (após trim)" do
    it = @task.checklist_items.new(content: "    ")
    assert_not it.valid?
  end

  test "normaliza content removendo espaços externos" do
    it = @task.checklist_items.create!(content: "  tarefa  ")
    assert_equal "tarefa", it.content
  end

  test "completed default false" do
    it = @task.checklist_items.create!(content: "x")
    assert_equal false, it.completed
  end

  test "scope ordered: por created_at, id" do
    a = @task.checklist_items.create!(content: "a")
    b = @task.checklist_items.create!(content: "b")
    assert_equal [ a.id, b.id ], @task.checklist_items.ordered.pluck(:id)
  end

  test "uma tarefa pode ter vários itens" do
    3.times { |i| @task.checklist_items.create!(content: "i#{i}") }
    assert_equal 3, @task.checklist_items.count
  end
end
