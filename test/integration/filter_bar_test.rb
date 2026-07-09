require "test_helper"

# PB-023e — filtros avançados com multi-seleção, chips removíveis, busca,
# estado na URL e sanitização por allowlist. Cobre os critérios de validação
# obrigatórios do contrato (Demandas/Tarefas como telas prioritárias).
class FilterBarTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @acme = Client.create!(name: "ACME")
    @globex = Client.create!(name: "GLOBEX")
  end

  # --- Demandas: multi-seleção -------------------------------------------
  test "Demandas: multi-seleção de prioridade retorna todos os valores marcados" do
    low  = Demand.create!(title: "Baixa", origin: "email", priority: "low", client: @acme)
    med  = Demand.create!(title: "Média", origin: "email", priority: "medium", client: @acme)
    high = Demand.create!(title: "Alta", origin: "email", priority: "high", client: @acme)

    get demands_path(priority: %w[low high])
    assert_response :success
    assert_select "td", text: /Baixa/
    assert_select "td", text: /Alta/
    assert_select "td", text: /Média/, count: 0
    assert_not_nil low && med && high
  end

  test "Demandas: multi-seleção combina critérios diferentes (E entre critérios)" do
    match = Demand.create!(title: "Casa", origin: "email", priority: "high", client: @acme)
    other_client = Demand.create!(title: "OutroCliente", origin: "email", priority: "high", client: @globex)
    other_prio = Demand.create!(title: "OutraPrio", origin: "email", priority: "low", client: @acme)

    get demands_path(priority: %w[high], client_id: [ @acme.id ])
    assert_response :success
    assert_select "td", text: /Casa/
    assert_select "td", text: /OutroCliente/, count: 0
    assert_select "td", text: /OutraPrio/, count: 0
    assert_not_nil other_client && other_prio
  end

  # --- Tarefas: multi-seleção --------------------------------------------
  test "Tarefas: multi-seleção de tipo retorna a união" do
    sup = @acme.tasks.create!(title: "Suporte X", type: "support")
    com = @acme.tasks.create!(title: "Comercial Y", type: "commercial")
    dev = @acme.tasks.create!(title: "Dev Z", type: "development")

    get tasks_path(type: %w[support commercial])
    assert_response :success
    assert_select "td", text: /Suporte X/
    assert_select "td", text: /Comercial Y/
    assert_select "td", text: /Dev Z/, count: 0
    assert_not_nil sup && com && dev
  end

  # --- Seleção reflete no <select multiple> (fonte de verdade + estado URL) ---
  test "seleção: valores marcados viram option[selected] no select multiple" do
    Demand.create!(title: "D", origin: "email", priority: "high", client: @acme)
    get demands_path(priority: %w[high], status: %w[pending])

    assert_select "select[name=?][multiple]", "priority[]" do
      assert_select "option[value=high][selected]"
      assert_select "option[value=low][selected]", count: 0
    end
    assert_select "select[name=?] option[value=pending][selected]", "status[]"
  end

  test "remover um valor preserva os demais (novo GET com um filtro a menos)" do
    Demand.create!(title: "Mantida", origin: "email", priority: "high", client: @acme)
    # após remover o chip de prioridade no cliente, o form reenvia só status
    get demands_path(status: %w[pending])
    assert_response :success
    assert_select "select[name=?] option[value=pending][selected]", "status[]"
    assert_select "select[name=?] option[selected]", "priority[]", count: 0
  end

  # --- Limpar filtros -----------------------------------------------------
  test "limpar filtros: link zera todos os critérios" do
    get demands_path(priority: %w[high], status: %w[pending], q: "abc")
    assert_response :success
    assert_select "a", text: "Limpar filtros"
    # o alvo do "Limpar" é a lista sem nenhum filtro
    assert_select "a[href=?]", demands_path, text: "Limpar filtros"
  end

  test "limpar filtros: em Clientes preserva a aba (extra)" do
    get clients_path(tab: "contacts", status: %w[active])
    assert_response :success
    assert_select "a[href=?]", clients_path(tab: "contacts"), text: "Limpar filtros"
  end

  # --- Estado na URL / reload --------------------------------------------
  test "estado na URL: recarregar com params multi-valor mantém seleção marcada" do
    @acme.tasks.create!(title: "S", type: "support")
    get tasks_path(type: %w[support commercial])
    assert_response :success
    # os dois valores vêm selecionados no <select multiple> (estado reflete a URL)
    assert_select "select[name=?][multiple]", "type[]" do
      assert_select "option[value=support][selected]"
      assert_select "option[value=commercial][selected]"
      assert_select "option[value=development][selected]", count: 0
    end
  end

  # --- Allowlist / valor inválido ----------------------------------------
  test "allowlist: valor inválido é ignorado sem quebrar nem filtrar" do
    keep = Demand.create!(title: "Fica", origin: "email", priority: "high", client: @acme)
    get demands_path(priority: %w[high inexistente], status: %w[__nope__])
    assert_response :success
    assert_select "td", text: /Fica/
    # só o valor válido fica selecionado; inválidos não viram option selecionada
    assert_select "select[name=?] option[selected]", "priority[]", count: 1
    assert_select "select[name=?] option[selected]", "status[]", count: 0
    assert_not_nil keep
  end

  test "allowlist: client_id inexistente é ignorado (sem seleção, sem filtro)" do
    Demand.create!(title: "Visível", origin: "email", priority: "low", client: @acme)
    get demands_path(client_id: [ "00000000-0000-0000-0000-000000000000" ])
    assert_response :success
    assert_select "td", text: /Visível/
    assert_select "select[name=?] option[selected]", "client_id[]", count: 0
  end

  # --- Compatibilidade com o formato escalar antigo ----------------------
  test "compatibilidade: param escalar antigo (?priority=high) continua filtrando" do
    Demand.create!(title: "AltaEscalar", origin: "email", priority: "high", client: @acme)
    Demand.create!(title: "BaixaEscalar", origin: "email", priority: "low", client: @acme)
    get demands_path(priority: "high")
    assert_response :success
    assert_select "td", text: /AltaEscalar/
    assert_select "td", text: /BaixaEscalar/, count: 0
  end

  # --- Componente renderizado (combobox token-input) ---------------------
  test "componente: renderiza combobox multi-seleção (select multiple + token input)" do
    get demands_path
    assert_response :success
    assert_select "div.combo[data-controller=combobox]"
    # fonte de verdade + fallback sem JS: <select multiple name='priority[]'>
    assert_select "select.combo__source[name=?][multiple]", "priority[]"
    # UI de token: campo de digitação + menu
    assert_select ".combo .combo__input"
    assert_select ".combo .combo__menu"
  end

  # --- Auto-submit (markup que habilita o comportamento JS) --------------
  test "auto-submit: form tem controller filter-bar e per_page auto-submete ao trocar" do
    get demands_path
    assert_response :success
    assert_select "form.filter-bar[data-controller~=?]", "filter-bar"
    assert_select "select[name=per_page][data-action*=?]", "filter-bar#submit"
  end

  # --- Fallback sem JS ----------------------------------------------------
  test "fallback sem JS: botão Filtrar presente + selects multiple submetíveis" do
    get demands_path
    assert_response :success
    # Filtrar segue no DOM (fallback; o CSS o oculta só quando o Stimulus ativa).
    assert_select "input[type=submit].filter-bar__submit"
    # a fonte de verdade multi-valor é submetível por form GET normal.
    assert_select "select[name=?][multiple]", "priority[]"
    assert_select "select[name=?][multiple]", "client_id[]"
  end
end
