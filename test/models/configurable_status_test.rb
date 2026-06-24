require "test_helper"

# PB-018 — status configurável de Tarefas/Projetos (modelo + integridade).
class ConfigurableStatusTest < ActiveSupport::TestCase
  test "seed/fixtures trazem os status iniciais de tarefas e projetos" do
    assert_equal %w[pending todo in_progress done canceled].sort,
                 ConfigurableStatus.keys_for("task").sort
    assert_equal %w[planning in_progress completed on_hold].sort,
                 ConfigurableStatus.keys_for("project").sort
  end

  test "key é única por entidade (mas pode repetir entre entidades)" do
    # 'in_progress' já existe em task e em project (fixtures) — ok entre entidades.
    dup = ConfigurableStatus.new(entity_type: "task", key: "todo", name: "Outro", color: "#111111", position: 9)
    assert_not dup.valid?
    assert dup.errors[:key].any?, "key duplicada na mesma entidade deve ser inválida"
  end

  test "key inválida (não snake_case ASCII) é rejeitada" do
    [ "Em Revisao", "em-revisao", "1status", "açao", "in progress" ].each do |bad|
      s = ConfigurableStatus.new(entity_type: "task", key: bad, name: "X", color: "#111111", position: 9)
      assert_not s.valid?, "#{bad.inspect} deveria ser inválida"
      assert s.errors[:key].any?
    end
    ok = ConfigurableStatus.new(entity_type: "task", key: "em_revisao", name: "Em revisão", color: "#111111", position: 9)
    assert ok.valid?, ok.errors.full_messages.to_sentence
  end

  test "cor deve ser hex; texto livre é rejeitado" do
    bad = ConfigurableStatus.new(entity_type: "task", key: "k1", name: "X", color: "red; }", position: 9)
    assert_not bad.valid?
    assert bad.errors[:color].any?
    good = ConfigurableStatus.new(entity_type: "task", key: "k2", name: "X", color: "#abc", position: 9)
    assert good.valid?
  end

  test "entity_type fora da allowlist é rejeitado" do
    s = ConfigurableStatus.new(entity_type: "demand", key: "k", name: "X", color: "#111111", position: 1)
    assert_not s.valid?
    assert s.errors[:entity_type].any?
  end

  test "in_use? reflete uso por tarefa/projeto" do
    client = Client.create!(name: "C", status: "active")
    task_status = ConfigurableStatus.find_by(entity_type: "task", key: "todo")
    assert_not task_status.in_use?
    Task.create!(title: "T", type: "support", status: "todo", client: client)
    assert task_status.in_use?
  end

  test "select_options só traz ativos + o status atual (mesmo inativo)" do
    canceled = ConfigurableStatus.find_by(entity_type: "task", key: "canceled")
    canceled.update!(active: false)

    keys = ConfigurableStatus.select_options("task").map(&:last)
    assert_not_includes keys, "canceled", "status inativo não deve aparecer para novos"

    keys_with_current = ConfigurableStatus.select_options("task", current_key: "canceled").map(&:last)
    assert_includes keys_with_current, "canceled", "o status atual do registro deve aparecer mesmo inativo"
  end

  test "label_for retorna o nome configurado e cai na key como fallback" do
    assert_equal "Em andamento", ConfigurableStatus.label_for("task", "in_progress")
    assert_equal "desconhecido", ConfigurableStatus.label_for("task", "desconhecido")
  end

  test "FK no banco impede excluir status em uso (rede de proteção)" do
    client = Client.create!(name: "C", status: "active")
    Task.create!(title: "T", type: "support", status: "in_progress", client: client)
    s = ConfigurableStatus.find_by(entity_type: "task", key: "in_progress")
    assert s.in_use?
    assert_raises(ActiveRecord::InvalidForeignKey) { s.destroy! }
  end
end
