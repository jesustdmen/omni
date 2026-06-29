require "test_helper"

# PB-020d (Triagem) — blocos de trabalho (rascunhos) via UI/controller.
class ConversationWorkBlocksTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 1, user_turns: 1, assistant_turns: 0, tool_calls: 0)
  end

  def create_block(**attrs)
    @conversation.work_blocks.create!({ period_date: Date.new(2026, 6, 29), day_period: "manha" }.merge(attrs))
  end

  def valid_params(**over)
    { work_block: { period_date: "2026-06-29", day_period: "manha", kind: "execution",
                    duration_seconds: 3600, summary: "validar 142 notas" }.merge(over) }
  end

  test "exige autenticação" do
    sign_out @user
    post conversation_work_blocks_path(@conversation), params: valid_params
    assert_redirected_to new_user_session_path
  end

  test "criar bloco (com auditoria e posição)" do
    assert_difference "ConversationWorkBlock.count", 1 do
      post conversation_work_blocks_path(@conversation), params: valid_params
    end
    b = @conversation.work_blocks.last
    assert_equal "manha", b.day_period
    assert_equal "execution", b.kind
    assert_equal "draft", b.status
    assert_equal 3600, b.duration_seconds
    assert_equal @user.id, b.created_by_id
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "blocos")
  end

  test "period_date/day_period inválidos não criam" do
    assert_no_difference "ConversationWorkBlock.count" do
      post conversation_work_blocks_path(@conversation), params: valid_params(period_date: "")
    end
    assert_no_difference "ConversationWorkBlock.count" do
      post conversation_work_blocks_path(@conversation), params: valid_params(day_period: "madrugada")
    end
  end

  test "kind fora da lista permitida não cria" do
    assert_no_difference "ConversationWorkBlock.count" do
      post conversation_work_blocks_path(@conversation), params: valid_params(kind: "analysis")
    end
  end

  test "editar campos do bloco (duração editável)" do
    b = create_block
    patch conversation_work_block_path(@conversation, b), params: valid_params(duration_seconds: 1800, summary: "novo")
    b.reload
    assert_equal 1800, b.duration_seconds
    assert_equal "novo", b.summary
    assert_equal @user.id, b.updated_by_id
  end

  test "confirmar, descartar e reabrir" do
    b = create_block
    patch conversation_work_block_path(@conversation, b), params: { work_block: { status: "confirmed" } }
    assert_equal "confirmed", b.reload.status
    patch conversation_work_block_path(@conversation, b), params: { work_block: { status: "discarded" } }
    assert_equal "discarded", b.reload.status
    patch conversation_work_block_path(@conversation, b), params: { work_block: { status: "draft" } }
    assert_equal "draft", b.reload.status
  end

  test "status inválido é ignorado (mantém o atual)" do
    b = create_block(status: "confirmed")
    patch conversation_work_block_path(@conversation, b), params: { work_block: { status: "lixo" } }
    assert_equal "confirmed", b.reload.status
  end

  test "remover bloco" do
    b = create_block
    assert_difference "ConversationWorkBlock.count", -1 do
      delete conversation_work_block_path(@conversation, b)
    end
  end

  test "não é possível mexer em bloco de outra conversa (escopo da URL → 404)" do
    outra = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}", message_count: 0, user_turns: 0, assistant_turns: 0, tool_calls: 0)
    b = outra.work_blocks.create!(period_date: Date.new(2026, 6, 29), day_period: "manha")
    patch conversation_work_block_path(@conversation, b), params: { work_block: { status: "confirmed" } }
    assert_response :not_found
    assert_equal "draft", b.reload.status
  end

  test "bloco NÃO cria TimeEntry/Task nem altera ConversationLink" do
    assert_no_difference [ "TimeEntry.count", "Task.count", "ConversationLink.count" ] do
      post conversation_work_blocks_path(@conversation), params: valid_params
    end
  end

  test "seção aparece no detalhe em modo triagem, em PT-BR" do
    create_block(summary: "bloco visível")
    get conversation_path(@conversation, mode: "triage")
    assert_response :success
    assert_select "h2", text: "Blocos de trabalho"
    assert_match "bloco visível", response.body
    assert_match "Manhã", response.body
    assert_select "input[type=submit][value=?]", "Adicionar bloco"
  end

  test "show normal (sem mode=triage) não mostra a seção de blocos" do
    create_block
    get conversation_path(@conversation)
    assert_response :success
    assert_select "h2", text: "Blocos de trabalho", count: 0
  end

  test "conversa pessoal: card mostra a mensagem e NÃO oferece criar bloco" do
    @conversation.update!(personal: true)
    get conversation_path(@conversation, mode: "triage")
    assert_response :success
    assert_match(/Blocos de trabalho não são gerados para conversas pessoais/i, response.body)
    assert_select "input[type=submit][value=?]", "Adicionar bloco", count: 0
  end

  test "conversa pessoal: criar bloco é BLOQUEADO no backend (não cria, avisa)" do
    @conversation.update!(personal: true)
    assert_no_difference "ConversationWorkBlock.count" do
      post conversation_work_blocks_path(@conversation), params: valid_params
    end
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "blocos")
    assert_match(/conversa marcada como pessoal/i, flash[:alert])
  end

  test "conversa pessoal: editar bloco existente é bloqueado (mantém o estado)" do
    b = create_block # criado enquanto a conversa NÃO é pessoal
    @conversation.update!(personal: true)
    patch conversation_work_block_path(@conversation, b), params: { work_block: { status: "confirmed" } }
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "blocos")
    assert_equal "draft", b.reload.status
    assert_match(/conversa marcada como pessoal/i, flash[:alert])
  end
end
