require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
  end

  test "name obrigatório" do
    project = @client.projects.build
    assert_not project.valid?
    assert project.errors[:name].any?
  end

  test "client obrigatório" do
    project = Project.new(name: "Portal")
    assert_not project.valid?
  end

  test "status default é planning" do
    project = @client.projects.create!(name: "Portal")
    assert_equal "planning", project.status
  end

  test "end_date não pode ser anterior a start_date" do
    project = @client.projects.build(name: "Portal", start_date: Date.new(2026, 5, 10), end_date: Date.new(2026, 5, 1))
    assert_not project.valid?
    assert project.errors[:end_date].any?
  end

  test "datas válidas quando end >= start" do
    project = @client.projects.build(name: "Portal", start_date: Date.new(2026, 5, 1), end_date: Date.new(2026, 5, 10))
    assert project.valid?
  end

  test "datas válidas quando só uma preenchida" do
    assert @client.projects.build(name: "Portal", start_date: Date.new(2026, 5, 1)).valid?
    assert @client.projects.build(name: "Portal", end_date: Date.new(2026, 5, 1)).valid?
  end

  test "cascade ao excluir cliente" do
    @client.projects.create!(name: "Portal")
    assert_difference "Project.count", -1 do
      @client.destroy
    end
  end
end
