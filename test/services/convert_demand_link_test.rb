require "test_helper"

# PB-004c — vínculo demanda↔tarefa na conversão + serviços (model/serviço level).
class ConvertDemandLinkTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
  end

  def pending_demand(attrs = {})
    Demand.create!({ title: "Suporte X", description: "detalhe", origin: "email", priority: "high", client: @client }.merge(attrs))
  end

  test "conversão cria a tarefa já vinculada (demand_id) — associação bidirecional" do
    d = pending_demand
    r = ConvertDemand.call(d)
    assert r.success?
    assert_equal d.id, r.task.demand_id
    assert_equal d.id, r.task.origin_demand.id          # task -> demanda
    assert_equal r.task.id, d.reload.converted_task.id  # demanda -> task
    assert d.converted?
    assert_not_nil d.converted_at
  end

  test "unicidade no model: segunda tarefa para a mesma demanda é inválida" do
    d = pending_demand
    ConvertDemand.call(d)
    dup = @client.tasks.build(title: "x", type: "support", status: "pending", demand_id: d.id)
    assert_not dup.valid?
    assert dup.errors[:demand_id].any?
  end

  test "unicidade no banco: índice único parcial barra demand_id duplicado" do
    d = pending_demand
    ConvertDemand.call(d)
    assert_raises(ActiveRecord::RecordNotUnique) do
      # contorna a validação do model para provar a barreira do banco
      @client.tasks.create!(title: "x", type: "support", status: "pending").update_column(:demand_id, d.id)
    end
  end

  test "conversão repetida falha sem criar segunda tarefa" do
    d = pending_demand
    ConvertDemand.call(d)
    assert_no_difference "Task.count" do
      r = ConvertDemand.call(d.reload)
      assert_not r.success?
      assert_match(/convertida/i, r.error)
    end
  end

  test "demanda sem cliente não converte" do
    d = Demand.create!(title: "D", origin: "email", priority: "low")
    assert_no_difference "Task.count" do
      assert_not ConvertDemand.call(d).success?
    end
    assert_equal "pending", d.reload.status
  end

  # --- exclusão da tarefa (DeleteTask) ------------------------------------

  test "excluir tarefa originada por demanda devolve a demanda para pending e limpa converted_at" do
    d = pending_demand
    task = ConvertDemand.call(d).task
    r = DeleteTask.call(task)
    assert r.success?
    assert_not Task.exists?(task.id)
    d.reload
    assert d.pending?
    assert_nil d.converted_at
    assert_nil d.converted_task
  end

  test "após exclusão, a demanda volta a ser convertível (nova conversão funciona)" do
    d = pending_demand
    DeleteTask.call(ConvertDemand.call(d).task)
    r = ConvertDemand.call(d.reload)
    assert r.success?
    assert_equal d.id, r.task.demand_id
  end

  test "tarefa SEM demanda é excluída normalmente" do
    task = @client.tasks.create!(title: "avulsa", type: "support", status: "todo")
    assert_difference "Task.count", -1 do
      assert DeleteTask.call(task).success?
    end
  end

  # --- exclusão da demanda -------------------------------------------------

  test "demanda vinculada não pode ser destruída (dependent: restrict_with_error)" do
    d = pending_demand
    ConvertDemand.call(d)
    assert_not d.reload.destroy
    assert Demand.exists?(d.id)
  end

  test "demanda pending sem vínculo pode ser destruída" do
    d = pending_demand
    assert_difference "Demand.count", -1 do
      assert d.destroy
    end
  end
end
