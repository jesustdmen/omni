require "test_helper"

# PB-020e (Triagem) — validação de tempo e gaps: subpágina com subtotal validado.
# Invariantes: só execução CONFIRMADA soma; gap confirmado é NÃO COBRÁVEL e não soma;
# draft pendente; discarded fora; conversa pessoal fora de tudo; NADA cria
# TimeEntry/Task nem altera ConversationLink.
class ConversationTimeValidationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 1, user_turns: 1, assistant_turns: 0, tool_calls: 0)
    @client = Client.create!(name: "ACME")
    @task = Task.create!(title: "Balanço", type: "support", status: "in_progress", client: @client)
  end

  DATE = Date.new(2026, 7, 1)

  def create_block(**attrs)
    @conversation.work_blocks.create!({ period_date: DATE, day_period: "manha" }.merge(attrs))
  end

  def confirmed_execution(seconds, **over)
    create_block(**{ status: "confirmed", duration_seconds: seconds, client: @client, task: @task }.merge(over))
  end

  def validation_path
    conversation_time_validation_path(@conversation)
  end

  test "exige autenticação" do
    sign_out @user
    get validation_path
    assert_redirected_to new_user_session_path
  end

  test "mostra subtotal por data/turno e total em HH:MM:SS, só com execução confirmada" do
    confirmed_execution(3600)                                      # manhã: 1h — soma
    confirmed_execution(1800, day_period: "tarde")                 # tarde: 30min — soma
    create_block(day_period: "tarde", duration_seconds: 900)       # draft — NÃO soma
    create_block(status: "discarded", duration_seconds: 7200)      # descartado — NÃO soma
    create_block(kind: "gap", status: "confirmed", gap_kind: "almoco",
                 duration_seconds: 2700, day_period: "tarde")      # gap — NÃO soma

    get validation_path
    assert_response :success
    assert_match "01:30:00", response.body                          # total validado (1h + 30min)
    assert_match "01:00:00", response.body                          # subtotal manhã
    assert_match "00:30:00", response.body                          # subtotal tarde
    assert_match "Validação de tempo", response.body
    assert_match(/1 pendente/, response.body)
    assert_match(/1 descartado/, response.body)
  end

  test "mensagem explícita: subtotal ainda não criou apontamento oficial" do
    confirmed_execution(3600)
    get validation_path
    assert_match(/Este subtotal ainda não criou apontamento oficial/i, response.body)
  end

  test "gap confirmado aparece como não cobrável, com classificação, e fora do subtotal" do
    create_block(kind: "gap", status: "confirmed", gap_kind: "pernoite", duration_seconds: 28_800)
    get validation_path
    assert_match(/Gap · não cobrável/i, response.body)
    assert_match "Pernoite", response.body
    assert_match "00:00:00", response.body # total validado zerado (gap nunca soma)
  end

  test "draft pendente mostra bloqueios (sem cliente/task) e NÃO oferece Confirmar" do
    create_block(duration_seconds: 900) # execução draft sem cliente/task
    get validation_path
    assert_match(/Antes de confirmar/i, response.body)
    assert_match(/cliente é obrigatório para validar tempo/i, response.body)
    assert_match(/tarefa é obrigatória para validar tempo/i, response.body)
    assert_select "button", text: "Confirmar", count: 0
  end

  test "draft pronto (duração+cliente+task) oferece Confirmar; confirmar volta à validação" do
    b = create_block(duration_seconds: 1200, client: @client, task: @task)
    get validation_path
    assert_select "button", text: "Confirmar"

    patch conversation_work_block_path(@conversation, b),
          params: { work_block: { status: "confirmed" }, return_to: validation_path }
    assert_redirected_to validation_path
    assert_equal "confirmed", b.reload.status
  end

  test "classificar gap pela validação e confirmar" do
    g = create_block(kind: "gap", duration_seconds: 2700)
    patch conversation_work_block_path(@conversation, g),
          params: { work_block: { gap_kind: "aguardando_cliente" }, return_to: validation_path }
    assert_redirected_to validation_path

    patch conversation_work_block_path(@conversation, g),
          params: { work_block: { status: "confirmed" }, return_to: validation_path }
    assert_equal "confirmed", g.reload.status
    assert_equal "aguardando_cliente", g.gap_kind
  end

  test "overlap entre execuções confirmadas gera alerta simples (não soma silenciosamente)" do
    base = Time.zone.local(2026, 7, 1, 9)
    confirmed_execution(3600, start_time: base, end_time: base + 1.hour)
    confirmed_execution(3600, start_time: base + 30.minutes, end_time: base + 90.minutes)
    get validation_path
    assert_match(/Janelas sobrepostas/i, response.body)
    assert_match "02:00:00", response.body # soma explícita, com alerta (não ajusta sozinho)
  end

  test "sem overlap não há alerta" do
    base = Time.zone.local(2026, 7, 1, 9)
    confirmed_execution(3600, start_time: base, end_time: base + 1.hour)
    confirmed_execution(3600, start_time: base + 2.hours, end_time: base + 3.hours, day_period: "tarde")
    get validation_path
    assert_no_match(/Janelas sobrepostas/i, response.body)
  end

  test "progresso 'X de Y confirmado(s)' exclui descartados" do
    confirmed_execution(3600)
    create_block(duration_seconds: 900)                       # draft
    create_block(status: "discarded", duration_seconds: 900)  # fora da conta
    get validation_path
    assert_match "1 de 2 confirmado(s)", response.body
  end

  test "conversa pessoal: página mostra mensagem e nenhum subtotal" do
    @conversation.update!(personal: true)
    get validation_path
    assert_response :success
    assert_match(/conversas pessoais/i, response.body)
    assert_no_match(/Subtotal validado/i, response.body)
  end

  test "nenhuma ação da validação cria TimeEntry/Task nem altera ConversationLink" do
    b = create_block(duration_seconds: 1200, client: @client, task: @task)
    g = create_block(kind: "gap", duration_seconds: 900)
    assert_no_difference [ "TimeEntry.count", "Task.count", "ConversationLink.count" ] do
      get validation_path
      patch conversation_work_block_path(@conversation, b),
            params: { work_block: { status: "confirmed" }, return_to: validation_path }
      patch conversation_work_block_path(@conversation, g),
            params: { work_block: { gap_kind: "pausa" }, return_to: validation_path }
      patch conversation_work_block_path(@conversation, g),
            params: { work_block: { status: "confirmed" }, return_to: validation_path }
      get validation_path
    end
  end

  test "return_to externo/malicioso é ignorado (volta ao detalhe em triagem)" do
    b = create_block(duration_seconds: 1200, client: @client, task: @task)
    patch conversation_work_block_path(@conversation, b),
          params: { work_block: { status: "confirmed" }, return_to: "https://evil.example" }
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "blocos")
  end

  test "card de blocos na Triagem tem atalho para a validação de tempo" do
    get conversation_path(@conversation, mode: "triage")
    assert_select "a[href=?]", validation_path, text: /Validar tempo/
  end
end
