require "test_helper"

# PB-004b — checklist persistente da tarefa.
class ChecklistItemsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "T", type: "support")
    @other = @client.tasks.create!(title: "Outra", type: "support")
  end

  def item(content: "fazer algo", completed: false, task: @task)
    task.checklist_items.create!(content: content, completed: completed)
  end

  # --- auth ----------------------------------------------------------------

  test "exige autenticação para criar" do
    sign_out @user
    assert_no_difference "ChecklistItem.count" do
      post task_checklist_items_path(@task), params: { checklist_item: { content: "x" } }
    end
    assert_redirected_to new_user_session_path
  end

  # --- criação -------------------------------------------------------------

  test "cria item e volta ao contexto da tarefa" do
    assert_difference "@task.checklist_items.count", 1 do
      post task_checklist_items_path(@task), params: { checklist_item: { content: "Escrever testes" } }
    end
    assert_redirected_to task_path(@task, anchor: "tab-detalhes")
    assert_equal "Escrever testes", @task.checklist_items.order(:created_at).last.content
  end

  test "trim do conteúdo (remove espaços externos)" do
    post task_checklist_items_path(@task), params: { checklist_item: { content: "  com espaços  " } }
    assert_equal "com espaços", @task.checklist_items.order(:created_at).last.content
  end

  test "conteúdo vazio (ou só espaços) é inválido" do
    assert_no_difference "ChecklistItem.count" do
      post task_checklist_items_path(@task), params: { checklist_item: { content: "   " } }
    end
    assert_redirected_to task_path(@task, anchor: "tab-detalhes")
  end

  # --- edição / marcar -----------------------------------------------------

  test "edita o texto" do
    it = item(content: "antigo")
    patch task_checklist_item_path(@task, it), params: { checklist_item: { content: "novo texto" } }
    assert_equal "novo texto", it.reload.content
  end

  test "marca e desmarca como concluído" do
    it = item(completed: false)
    patch task_checklist_item_path(@task, it), params: { checklist_item: { completed: true } }
    assert it.reload.completed
    patch task_checklist_item_path(@task, it), params: { checklist_item: { completed: false } }
    assert_not it.reload.completed
  end

  # --- exclusão ------------------------------------------------------------

  test "exclui o item" do
    it = item
    assert_difference "ChecklistItem.count", -1 do
      delete task_checklist_item_path(@task, it)
    end
    assert_redirected_to task_path(@task, anchor: "tab-detalhes")
  end

  # --- ordem / cascade / isolamento ----------------------------------------

  test "ordem estável por created_at, id" do
    a = item(content: "1")
    b = item(content: "2")
    c = item(content: "3")
    assert_equal [ a.id, b.id, c.id ], @task.checklist_items.ordered.pluck(:id)
  end

  test "excluir a tarefa remove seus itens (cascade)" do
    item; item
    assert_difference "ChecklistItem.count", -2 do
      @task.destroy
    end
  end

  test "isolamento: não atualiza item de outra tarefa cruzando IDs" do
    foreign = item(task: @other, content: "da outra")
    patch task_checklist_item_path(@task, foreign), params: { checklist_item: { content: "hack" } }
    assert_response :not_found
    assert_equal "da outra", foreign.reload.content
  end

  test "isolamento: não exclui item de outra tarefa cruzando IDs" do
    foreign = item(task: @other)
    assert_no_difference "ChecklistItem.count" do
      delete task_checklist_item_path(@task, foreign)
    end
    assert_response :not_found
  end

  # --- params não permitidos -----------------------------------------------

  test "task_id não é atribuível via params (item fica na tarefa da URL)" do
    post task_checklist_items_path(@task), params: { checklist_item: { content: "x", task_id: @other.id } }
    created = ChecklistItem.order(:created_at).last
    assert_equal @task.id, created.task_id, "task_id deve vir da URL, não dos params"
  end

  test "completed inválido/estranho não quebra (ignora chaves extras)" do
    it = item
    patch task_checklist_item_path(@task, it), params: { checklist_item: { content: "ok", foo: "bar" } }
    assert_equal "ok", it.reload.content
  end

  # --- UI: contador / estado vazio / itens ---------------------------------

  test "página da tarefa mostra checklist vazio com contador 0/0" do
    get task_path(@task)
    assert_response :success
    assert_select ".checklist h2", "Checklist"
    assert_select ".checklist .muted", /0\/0 conclu/
    assert_select ".checklist", /Nenhum item no checklist ainda/
    assert_select ".checklist__add" # form de adicionar sempre presente
  end

  test "página da tarefa lista itens, contador e marca concluído" do
    item(content: "feito", completed: true)
    item(content: "pendente", completed: false)
    get task_path(@task)
    assert_select ".checklist .muted", %r{1/2 conclu}
    assert_select ".checklist__item--done .checklist__content", /feito/
    assert_select ".checklist__content", /pendente/
  end

  test "edição fica sob demanda: a linha (<details>) alterna exibição↔edição sem JS" do
    item(content: "editável")
    get task_path(@task)
    # summary = modo exibição (texto + lápis); conteúdo aberto = form de edição.
    assert_select "details.checklist__row > summary .checklist__content", /editável/
    assert_select "details.checklist__row form.checklist__edit input[name=?]", "checklist_item[content]"
    assert_select "details.checklist__row form.checklist__edit", /Cancelar|Salvar/
  end

  # --- regressão da página da tarefa + PB-003 ------------------------------

  test "regressão: página da tarefa segue renderizando abas e histórico de apontamentos" do
    t = Time.current
    @task.time_entries.create!(start_time: t, end_time: t + 600.seconds)
    get task_path(@task)
    assert_response :success
    assert_select "#tab-detalhes"
    assert_select "#tab-time", /Histórico de Apontamentos/
    assert_select ".checklist"
  end
end
