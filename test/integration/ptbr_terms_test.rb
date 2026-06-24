require "test_helper"

# PB-018 (termos PT-BR) — Tipo de tarefa, Origem e Prioridade de demanda exibidos
# em português (listas fixas; não configuráveis). Sem mudança de valores armazenados.
class PtbrTermsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @client = Client.create!(name: "ACME")
  end

  test "model: rótulos PT-BR de tipo/origem/prioridade" do
    assert_equal "Suporte", Task.type_label("support")
    assert_equal "Dúvida", Task.type_label("question")
    assert_equal "Desenvolvimento", Task.type_label("development")
    assert_equal "E-mail", Demand.origin_label("email")
    assert_equal "WhatsApp", Demand.origin_label("whatsapp")
    assert_equal "Baixa", Demand.priority_label("low")
    assert_equal "Alta", Demand.priority_label("high")
  end

  test "lista e detalhe de tarefas mostram o tipo em PT-BR (sem inglês cru)" do
    Task.create!(title: "T", type: "development", status: "todo", client: @client)
    get tasks_path
    assert_select "span.badge", text: "Desenvolvimento"
    assert_select "select[name='type'] option", text: "Suporte"
    refute_match(/>Development</, response.body)
  end

  test "lista e detalhe de demandas mostram origem/prioridade em PT-BR" do
    Demand.create!(title: "D", origin: "whatsapp", priority: "high", status: "pending", client: @client)
    get demands_path
    assert_match("WhatsApp", response.body)
    assert_select "span.badge", text: "Alta"
    assert_select "select[name='origin'] option", text: "Reunião"
    assert_select "select[name='priority'] option", text: "Média"
    refute_match(/>Whatsapp</, response.body) # não deve aparecer o humanize cru
  end

  test "form de tarefa lista tipos em PT-BR" do
    get new_task_path
    assert_select "select[name='task[type]'] option", text: "Implementação"
    assert_select "select[name='task[type]'] option", text: "Comercial"
  end
end
