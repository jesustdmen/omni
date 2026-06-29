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

  # ── Sugestão por IA local (ação manual) ──────────────────────────────────────
  # Client FAKE injetado por stub de Ai::OllamaClient.new: a suíte exercita o
  # serviço real (parse/normalização) + controller, SEM rede e SEM Ollama real.
  class ClienteFake
    attr_reader :chamado

    def initialize(resposta: nil, erro: nil)
      @resposta = resposta
      @erro = erro
      @chamado = false
    end

    def chat(messages:, model: nil, options: {}, format: nil)
      @chamado = true # registra que a IA foi efetivamente acionada
      raise Ai::OllamaClient::Error, @erro if @erro

      @resposta
    end
  end

  # Substitui Ai::OllamaClient.new pelo client fake durante o bloco (sem mocha/minitest-mock).
  # Como OllamaClient não define `self.new`, remover o singleton restaura o comportamento padrão.
  # O bloco recebe o fake para inspeção (ex.: confirmar que a IA NÃO foi chamada).
  def com_ia(resposta: nil, erro: nil)
    fake = ClienteFake.new(resposta: resposta, erro: erro)
    Ai::OllamaClient.define_singleton_method(:new) { |*_args, **_kwargs| fake }
    yield fake
  ensure
    Ai::OllamaClient.singleton_class.send(:remove_method, :new)
  end

  # Injeta um CONTEXTO textual durante o bloco (ConversationContextBuilder define
  # `self.call`, então restauramos o método original ao fim).
  def com_contexto(text = "Turno 7 — usuário: validei 142 notas fiscais")
    original = Ai::ConversationContextBuilder.method(:call)
    resultado = Ai::ConversationContextBuilder::Result.new(text: text, status: :ok, turns_used: 2)
    Ai::ConversationContextBuilder.define_singleton_method(:call) { |**_kw| resultado }
    yield
  ensure
    Ai::ConversationContextBuilder.define_singleton_method(:call, original)
  end

  # Força o STATUS do contexto (sem texto): :indisponivel (índice :stale/não construído)
  # ou :sem_texto (índice ok porém sem texto útil). A UI/controller dão mensagens distintas.
  def com_contexto_status(status)
    original = Ai::ConversationContextBuilder.method(:call)
    resultado = Ai::ConversationContextBuilder::Result.new(text: "", status: status, turns_used: 0)
    Ai::ConversationContextBuilder.define_singleton_method(:call) { |**_kw| resultado }
    yield
  ensure
    Ai::ConversationContextBuilder.define_singleton_method(:call, original)
  end

  # Força o STATUS do LazyLoader usado pelo `show` (gating do botão de IA): :ok (índice
  # íntegro), :stale (reindex em curso/obsoleto), :empty (índice ainda não construído).
  def com_loader_status(status, total: 0, turns: [])
    original = ConversationTurns::LazyLoader.method(:call)
    resultado = ConversationTurns::LazyLoader::Result.new(
      status: status, turns: turns, total: total, limit: nil, offset: 0, mismatched: 0, turn_source: nil
    )
    ConversationTurns::LazyLoader.define_singleton_method(:call) { |**_kw| resultado }
    yield
  ensure
    ConversationTurns::LazyLoader.define_singleton_method(:call, original)
  end

  def conteudo_ia(hash)
    JSON.generate(hash)
  end

  test "botão de sugerir com IA aparece no modo triagem (índice íntegro :ok)" do
    com_loader_status(:ok, total: 3) do
      get conversation_path(@conversation, mode: "triage")
      assert_response :success
      assert_select "button", text: "Sugerir atividades com IA"
    end
  end

  test "índice :stale: não oferece IA, mostra aviso de índice + link p/ sincronização" do
    com_loader_status(:stale) do
      get conversation_path(@conversation, mode: "triage")
      assert_response :success
      assert_select "button", text: "Sugerir atividades com IA", count: 0
      assert_match(/Índice de turnos em atualização ou desatualizado/i, response.body)
      assert_select "a[href=?]", sync_runs_path
    end
  end

  test "índice :empty (ainda não construído): não oferece IA, mostra aviso de índice" do
    com_loader_status(:empty) do
      get conversation_path(@conversation, mode: "triage")
      assert_response :success
      assert_select "button", text: "Sugerir atividades com IA", count: 0
      assert_match(/Índice de turnos em atualização ou desatualizado/i, response.body)
    end
  end

  test "conversa pessoal: botão de IA não aparece, mostra explicação" do
    @conversation.update!(personal: true)
    get conversation_path(@conversation, mode: "triage")
    assert_select "button", text: "Sugerir atividades com IA", count: 0
    assert_match(/Sugestão por IA desativada/i, response.body)
  end

  test "sugestão cria rascunhos com source ia_local e status Rascunho" do
    resposta = conteudo_ia(
      "objetivo_principal" => "Entregar balanço",
      "atividades" => [
        { "titulo" => "Validar notas", "descricao" => "142 NFs", "evidencia" => "Turno 7 — usuário", "confianca" => "alta" },
        { "titulo" => "Ajustar XMLs", "evidencia" => "Turno 9 — assistente", "confianca" => "duvidosa" }
      ]
    )
    com_contexto do
      com_ia(resposta: resposta) do
        assert_difference "ConversationActivityDraft.count", 2 do
          post suggest_conversation_activity_drafts_path(@conversation)
        end
      end
    end
    criadas = @conversation.activity_drafts.where(source: "ia_local")
    assert_equal 2, criadas.count
    assert criadas.all?(&:draft?)
    assert_equal @user.id, criadas.first.created_by_id
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "atividades")
  end

  test "sugestão NÃO cria Task, TimeEntry nem ConversationLink" do
    resposta = conteudo_ia("atividades" => [ { "titulo" => "Validar notas", "evidencia" => "Turno 7", "confianca" => "media" } ])
    com_contexto do
      com_ia(resposta: resposta) do
        assert_no_difference [ "Task.count", "TimeEntry.count", "ConversationLink.count" ] do
          post suggest_conversation_activity_drafts_path(@conversation)
        end
      end
    end
  end

  test "IA retornando vazio não cria rascunhos e informa o usuário" do
    com_contexto do
      com_ia(resposta: conteudo_ia("atividades" => [])) do
        assert_no_difference "ConversationActivityDraft.count" do
          post suggest_conversation_activity_drafts_path(@conversation)
        end
      end
    end
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "atividades")
    assert_match(/não sugeriu atividades/i, flash[:notice])
  end

  test "erro da IA não cria rascunhos e redireciona com alerta (sem 500)" do
    com_contexto do
      com_ia(erro: "Ollama indisponível") do
        assert_no_difference "ConversationActivityDraft.count" do
          post suggest_conversation_activity_drafts_path(@conversation)
        end
      end
    end
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "atividades")
    assert_match(/não foi possível obter sugestões/i, flash[:alert])
  end

  test "índice indisponível (sem índice construído): POST não chama a IA e avisa sobre o índice" do
    # Sem turnos indexados, o builder real retorna status :indisponivel → server-side
    # barra a IA e a mensagem fala de ÍNDICE (não de erro da IA).
    com_ia(resposta: conteudo_ia("atividades" => [ { "titulo" => "X", "evidencia" => "y" } ])) do |fake|
      assert_no_difference "ConversationActivityDraft.count" do
        post suggest_conversation_activity_drafts_path(@conversation)
      end
      assert_not fake.chamado, "A IA não deve ser chamada com índice indisponível"
    end
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "atividades")
    assert_match(/Índice de turnos em atualização ou desatualizado/i, flash[:alert])
  end

  test "índice ok porém sem texto útil (:sem_texto): avisa contexto insuficiente (sem chamar a IA)" do
    com_contexto_status(:sem_texto) do
      com_ia(resposta: conteudo_ia("atividades" => [ { "titulo" => "X", "evidencia" => "y" } ])) do |fake|
        assert_no_difference "ConversationActivityDraft.count" do
          post suggest_conversation_activity_drafts_path(@conversation)
        end
        assert_not fake.chamado, "A IA não deve ser chamada sem texto útil"
      end
    end
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "atividades")
    assert_match(/contexto textual suficiente/i, flash[:alert])
  end

  test "conversa pessoal: POST não envia à IA, não cria nada e avisa" do
    @conversation.update!(personal: true)
    com_ia(resposta: conteudo_ia("atividades" => [])) do |fake|
      assert_no_difference "ConversationActivityDraft.count" do
        post suggest_conversation_activity_drafts_path(@conversation)
      end
      assert_not fake.chamado, "A IA não deve ser acionada em conversa pessoal"
    end
    assert_redirected_to conversation_path(@conversation, mode: "triage", anchor: "atividades")
    assert_match(/conversa pessoal/i, flash[:alert])
  end

  test "sugestão exige autenticação" do
    sign_out @user
    post suggest_conversation_activity_drafts_path(@conversation)
    assert_redirected_to new_user_session_path
  end
end
