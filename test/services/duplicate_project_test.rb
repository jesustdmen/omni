require "test_helper"

# PB-007 — serviço de duplicação de projeto (campos autorizados; transacional).
class DuplicateProjectTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
  end

  def project(attrs = {})
    Project.create!({ client: @client, name: "Original", status: "completed",
                      description: "desc", budget: "R$ 99",
                      start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 2, 1) }.merge(attrs))
  end

  test "copia cliente/descrição/nome (cópia) e zera status para planning" do
    r = DuplicateProject.call(project)
    assert r.success?
    c = r.project
    assert_equal "Original (cópia)", c.name
    assert_equal "desc", c.description
    assert_equal @client.id, c.client_id
    assert_equal "planning", c.status
  end

  test "NÃO copia orçamento, datas nem tarefas" do
    orig = project
    orig.tasks.create!(client: @client, title: "T", type: "support")
    c = DuplicateProject.call(orig).project
    assert_nil c.budget
    assert_nil c.start_date
    assert_nil c.end_date
    assert_equal 0, c.tasks.count
  end

  test "falha não deixa projeto parcial (rollback)" do
    orig = project(name: "X")
    # força a criação da cópia a falhar (RecordInvalid) → rollback total.
    original = Project.method(:create!)
    Project.define_singleton_method(:create!) { |*_a, **_k| raise ActiveRecord::RecordInvalid.new(Project.new) }
    begin
      assert_no_difference "Project.count" do
        r = DuplicateProject.call(orig)
        assert_not r.success?
        assert r.error.present?
      end
    ensure
      Project.singleton_class.send(:remove_method, :create!)
      Project.define_singleton_method(:create!, original)
    end
  end
end
