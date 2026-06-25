require "test_helper"

# PB-020 (Triagem) — atividades de 2º nível (rascunhos manuais) via UI/controller.
class ConversationActivityDraftsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 1, user_turns: 1, assistant_turns: 0, tool_calls: 0)
  end

  def draft(**attrs)
    @conversation.activity_drafts.create!({ title: "Atividade" }.merge(attrs))
  end

  test "exige autenticação" do
    sign_out @user
    post conversation_activity_drafts_path(@conversation), params: { activity_draft: { title: "X" } }
    assert_redirected_to new_user_session_path
  end

  test "criar atividade manual (com auditoria e posição)" do
    assert_difference "ConversationActivityDraft.count", 1 do
      post conversation_activity_drafts_path(@conversation), params: { activity_draft: { title: "Validar notas", description: "142 NFs" } }
    end
    d = @conversation.activity_drafts.last
    assert_equal "Validar notas", d.title
    assert_equal "draft", d.status
    assert_equal @user.id, d.created_by_id
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "atividades")
  end

  test "título vazio não cria" do
    assert_no_difference "ConversationActivityDraft.count" do
      post conversation_activity_drafts_path(@conversation), params: { activity_draft: { title: "  " } }
    end
  end

  test "editar título e descrição" do
    d = draft(title: "Antigo")
    patch conversation_activity_draft_path(@conversation, d), params: { activity_draft: { title: "Novo", description: "desc" } }
    d.reload
    assert_equal "Novo", d.title
    assert_equal "desc", d.description
    assert_equal @user.id, d.updated_by_id
  end

  test "confirmar, descartar e reabrir" do
    d = draft
    patch conversation_activity_draft_path(@conversation, d), params: { activity_draft: { status: "confirmed" } }
    assert_equal "confirmed", d.reload.status
    patch conversation_activity_draft_path(@conversation, d), params: { activity_draft: { status: "discarded" } }
    assert_equal "discarded", d.reload.status
    patch conversation_activity_draft_path(@conversation, d), params: { activity_draft: { status: "draft" } }
    assert_equal "draft", d.reload.status
  end

  test "status inválido é ignorado (mantém o atual)" do
    d = draft(status: "confirmed")
    patch conversation_activity_draft_path(@conversation, d), params: { activity_draft: { status: "lixo" } }
    assert_equal "confirmed", d.reload.status
  end

  test "remover atividade" do
    d = draft
    assert_difference "ConversationActivityDraft.count", -1 do
      delete conversation_activity_draft_path(@conversation, d)
    end
  end

  test "não é possível mexer em atividade de outra conversa (escopo da URL → 404)" do
    outra = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}", message_count: 0, user_turns: 0, assistant_turns: 0, tool_calls: 0)
    d = outra.activity_drafts.create!(title: "De outra")
    # item de outra conversa não é encontrado no escopo da conversa da URL → 404, sem alterar nada.
    patch conversation_activity_draft_path(@conversation, d), params: { activity_draft: { status: "confirmed" } }
    assert_response :not_found
    assert_equal "draft", d.reload.status
  end

  test "atividade NÃO cria Task, TimeEntry nem ConversationLink" do
    assert_no_difference [ "Task.count", "TimeEntry.count", "ConversationLink.count" ] do
      post conversation_activity_drafts_path(@conversation), params: { activity_draft: { title: "X" } }
    end
  end

  test "seção aparece no detalhe em modo triagem, em PT-BR" do
    draft(title: "Atividade visível")
    get conversation_path(@conversation, mode: "triage")
    assert_response :success
    assert_select "h2", text: "Atividades da conversa"
    assert_match "Atividade visível", response.body
    assert_match "Rascunho", response.body
    assert_select "input[type=submit][value=?]", "Adicionar atividade"
  end

  test "conversa pessoal mantém conteúdo dos turnos oculto, mas atividades funcionam" do
    @conversation.update!(personal: true)
    draft(title: "Prep pessoal")
    get conversation_path(@conversation, mode: "triage")
    assert_match(/conteúdo dos turnos está oculto/i, response.body)
    assert_match "Atividades da conversa", response.body
  end

  test "show normal (sem mode=triage) não mostra a seção de atividades" do
    draft(title: "Não deve aparecer no show normal")
    get conversation_path(@conversation)
    assert_response :success
    assert_select "h2", text: "Atividades da conversa", count: 0
  end
end
