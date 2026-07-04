require "test_helper"

# PB-020d (Triagem) — bloco de trabalho (rascunho por turno/dia da conversa).
class ConversationWorkBlockTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 1, user_turns: 1, assistant_turns: 0, tool_calls: 0)
  end

  def block(**attrs)
    @conversation.work_blocks.new({ period_date: Date.new(2026, 6, 29), day_period: "manha" }.merge(attrs))
  end

  # PB-020e — atributos mínimos para CONFIRMAR uma execução (validar tempo):
  # duração > 0 + cliente + tarefa. Criados sob demanda.
  def confirmable_attrs(**over)
    @client ||= Client.create!(name: "ACME")
    @task ||= Task.create!(title: "T", type: "support", status: "in_progress", client: @client)
    { status: "confirmed", duration_seconds: 3600, client: @client, task: @task }.merge(over)
  end

  test "defaults: kind execution, status draft, source manual, duration 0" do
    b = block
    assert b.valid?
    assert_equal "execution", b.kind
    assert_equal "draft", b.status
    assert_equal "manual", b.source
    assert_equal 0, b.duration_seconds
  end

  test "period_date é obrigatório" do
    assert_not block(period_date: nil).valid?
  end

  test "day_period exige lista permitida (manha|tarde|noite)" do
    assert block(day_period: "tarde").valid?
    assert_not block(day_period: "madrugada").valid?
  end

  test "kind exige lista permitida (execution|gap)" do
    assert block(kind: "gap").valid?
    assert_not block(kind: "analysis").valid?
  end

  test "status exige lista permitida" do
    assert block(**confirmable_attrs).valid? # confirmar exige regras PB-020e (duração/cliente/task)
    assert block(status: "discarded").valid?
    assert_not block(status: "done").valid?
  end

  test "source exige lista permitida" do
    assert block(source: "ia_local").valid?
    assert_not block(source: "gemma").valid?
  end

  test "duration_seconds não pode ser negativa" do
    assert_not block(duration_seconds: -1).valid?
    assert block(duration_seconds: 3600).valid?
  end

  test "fim não pode ser anterior ao início; tempo é opcional (evidência)" do
    base = Time.utc(2026, 6, 29, 11)
    assert_not block(start_time: base, end_time: base - 1.hour).valid?
    assert block(start_time: base, end_time: base + 1.hour).valid?
    assert block(start_time: nil, end_time: nil).valid?
  end

  test "client/project/task são opcionais (rascunho não exige task)" do
    assert block(client_id: nil, project_id: nil, task_id: nil).valid?
  end

  test "rótulos PT-BR" do
    assert_equal "Manhã", block(day_period: "manha").day_period_label
    assert_equal "Execução", block(kind: "execution").kind_label
    assert_equal "Gap", block(kind: "gap").kind_label
    assert_equal "Rascunho", block(status: "draft").status_label
    assert_equal "IA local", block(source: "ia_local").source_label
  end

  test "ordered ordena por period_date e position" do
    b2 = @conversation.work_blocks.create!(period_date: Date.new(2026, 6, 30), day_period: "manha", position: 0)
    b1 = @conversation.work_blocks.create!(period_date: Date.new(2026, 6, 29), day_period: "tarde", position: 1)
    b0 = @conversation.work_blocks.create!(period_date: Date.new(2026, 6, 29), day_period: "manha", position: 0)
    assert_equal [ b0.id, b1.id, b2.id ], @conversation.work_blocks.ordered.pluck(:id)
  end

  test "conversa pessoal não permite bloco (backstop de modelo)" do
    @conversation.update!(personal: true)
    b = block
    assert_not b.valid?
    assert b.errors[:base].any?
  end

  test "normaliza summary/notes vazios para nil" do
    b = block(summary: "   ", notes: "")
    b.valid?
    assert_nil b.summary
    assert_nil b.notes
  end

  test "ao destruir a conversa, os blocos somem" do
    @conversation.work_blocks.create!(period_date: Date.new(2026, 6, 29), day_period: "manha")
    assert_difference("ConversationWorkBlock.count", -1) { @conversation.destroy }
  end

  # ── PB-020e — validação de tempo e gaps ─────────────────────────────────────

  test "gap confirmado exige gap_kind" do
    b = block(**confirmable_attrs(kind: "gap", client: nil, task: nil))
    assert_not b.valid?
    assert_match(/classifique o gap/i, b.errors[:base].join("; "))

    b.gap_kind = "almoco"
    assert b.valid?
  end

  test "gap_kind exige lista permitida (fora_vscode NÃO é gap)" do
    assert_not block(kind: "gap", gap_kind: "fora_vscode").valid?
    assert_not block(kind: "gap", gap_kind: "ferias").valid?
    assert block(kind: "gap", gap_kind: "pernoite").valid?
  end

  test "execution não aceita gap_kind (mesmo em rascunho)" do
    b = block(kind: "execution", gap_kind: "pausa")
    assert_not b.valid?
    assert_match(/só se aplica a blocos de gap/i, b.errors[:base].join("; "))
  end

  test "gap_kind vazio normaliza para nil (form compartilhado envia string vazia)" do
    b = block(kind: "execution", gap_kind: "  ")
    assert b.valid?
    assert_nil b.gap_kind
  end

  test "bloco confirmado exige duração > 0" do
    b = block(**confirmable_attrs(duration_seconds: 0))
    assert_not b.valid?
    assert_match(/duração deve ser maior que zero/i, b.errors[:base].join("; "))
  end

  test "execution confirmado exige cliente e tarefa (validar tempo)" do
    sem_cliente = block(**confirmable_attrs(client: nil))
    assert_not sem_cliente.valid?
    assert_match(/cliente é obrigatório/i, sem_cliente.errors[:base].join("; "))

    sem_task = block(**confirmable_attrs(task: nil))
    assert_not sem_task.valid?
    assert_match(/tarefa é obrigatória/i, sem_task.errors[:base].join("; "))

    assert block(**confirmable_attrs).valid?
  end

  test "mensagens de validação PT-BR sem prefixo de atributo em inglês (gate PT-BR)" do
    b = block(**confirmable_attrs(duration_seconds: 0, client: nil, task: nil))
    b.valid?
    texto = b.errors.full_messages.join("; ")
    assert_no_match(/duration|client\b|task\b|gap kind|is not included/i, texto)
  end

  test "gap confirmado NÃO exige cliente/tarefa (não valida tempo), só classificação" do
    b = block(**confirmable_attrs(kind: "gap", gap_kind: "aguardando_cliente", client: nil, task: nil))
    assert b.valid?
  end

  test "draft e discarded seguem livres (regras PB-020d preservadas)" do
    assert block(status: "draft", duration_seconds: 0).valid?
    assert block(status: "discarded", duration_seconds: 0).valid?
  end

  test "counts_for_subtotal? só para execução confirmada" do
    assert block(**confirmable_attrs).counts_for_subtotal?
    assert_not block(**confirmable_attrs(kind: "gap", gap_kind: "pausa")).counts_for_subtotal?
    assert_not block(status: "draft").counts_for_subtotal?
  end

  test "validation_blockers explica pendências antes de confirmar" do
    b = block(duration_seconds: 0)
    assert_includes b.validation_blockers.join(", "), "duração"
    assert_includes b.validation_blockers.join(", "), "cliente"
    assert_includes b.validation_blockers.join(", "), "tarefa"

    g = block(kind: "gap", duration_seconds: 900)
    assert_includes g.validation_blockers.join(", "), "gap"

    assert_empty block(**confirmable_attrs(status: "draft")).validation_blockers
  end
end
