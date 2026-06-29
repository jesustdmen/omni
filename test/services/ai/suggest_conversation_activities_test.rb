require "test_helper"

# IA local (Ollama) — serviço de sugestão de atividades. Testado com CLIENT FAKE e
# CONTEXTO FAKE (sem rede, sem Ollama, sem arquivo de turnos). Só propõe em memória.
class Ai::SuggestConversationActivitiesTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(
      thread_id: "t-#{SecureRandom.hex(4)}", title: "Balanço de estoque",
      workspace_hash: "ws-abc", first_ts: Time.utc(2026, 6, 10, 9), last_ts: Time.utc(2026, 6, 10, 12),
      message_count: 40, user_turns: 20, assistant_turns: 20, tool_calls: 5
    )
  end

  # Client fake: devolve texto fixo (como message.content) ou simula erro. Registra
  # as mensagens recebidas p/ auditar o prompt.
  class ClienteFake
    attr_reader :messages, :format

    def initialize(resposta: nil, erro: nil)
      @resposta = resposta
      @erro = erro
    end

    def chat(messages:, model: nil, options: {}, format: nil)
      @messages = messages
      @format = format
      raise Ai::OllamaClient::Error, @erro if @erro

      @resposta
    end
  end

  # Client que NUNCA deve ser chamado (contexto insuficiente).
  class ClienteProibido
    def chat(**)
      raise "A IA não deveria ser chamada sem contexto"
    end
  end

  # Builder de contexto fake: devolve um texto fixo (ou vazio).
  class ContextoFake
    def initialize(text:)
      @text = text
    end

    def call(conversation:)
      status = @text.to_s.strip.empty? ? :sem_texto : :ok
      Ai::ConversationContextBuilder::Result.new(text: @text, status: status, turns_used: 2)
    end
  end

  def conteudo(hash)
    JSON.generate(hash)
  end

  def contexto_ok(text = "Turno 7 — usuário: validei 142 notas fiscais de entrada")
    ContextoFake.new(text: text)
  end

  def chamar(resposta:, contexto: nil)
    Ai::SuggestConversationActivities.call(
      conversation: @conversation, client: ClienteFake.new(resposta: resposta), context_builder: contexto || contexto_ok
    )
  end

  test "parseia JSON válido em objetivo e atividades" do
    resposta = conteudo(
      "objetivo_principal" => "Entregar balanço auditado",
      "atividades" => [
        { "titulo" => "Validar notas de entrada", "descricao" => "142 NFs", "evidencia" => "Turno 7 — usuário", "confianca" => "alta" }
      ]
    )
    result = chamar(resposta: resposta)

    assert result.sucesso?
    assert_equal "Entregar balanço auditado", result.objetivo_principal
    assert_equal 1, result.atividades.size
    assert_equal "Validar notas de entrada", result.atividades.first.titulo
    assert_equal "alta", result.atividades.first.confianca
  end

  test "confiança inválida é normalizada para o padrão (media)" do
    resposta = conteudo("atividades" => [ { "titulo" => "Validar notas", "evidencia" => "Turno 7", "confianca" => "duvidosa" } ])
    assert_equal "media", chamar(resposta: resposta).atividades.first.confianca
  end

  test "confiança ausente também vira o padrão (media)" do
    resposta = conteudo("atividades" => [ { "titulo" => "Validar notas", "evidencia" => "Turno 7" } ])
    assert_equal "media", chamar(resposta: resposta).atividades.first.confianca
  end

  test "atividade sem título é descartada" do
    resposta = conteudo("atividades" => [ { "titulo" => "  ", "evidencia" => "Turno 7" }, { "titulo" => "Válida", "evidencia" => "Turno 8" } ])
    result = chamar(resposta: resposta)

    assert_equal 1, result.atividades.size
    assert_equal "Válida", result.atividades.first.titulo
  end

  test "atividade SEM evidência é descartada" do
    resposta = conteudo("atividades" => [
      { "titulo" => "Sem evidência", "descricao" => "x" },
      { "titulo" => "Com evidência", "evidencia" => "Turno 9 — assistente" }
    ])
    result = chamar(resposta: resposta)

    assert_equal 1, result.atividades.size
    assert_equal "Com evidência", result.atividades.first.titulo
  end

  test "atividade com título meta/genérico é descartada" do
    resposta = conteudo("atividades" => [
      { "titulo" => "Analisar a conversa", "evidencia" => "Turno 1" },
      { "titulo" => "Auditar a comunicação do time", "evidencia" => "Turno 2" },
      { "titulo" => "Validar 142 notas", "evidencia" => "Turno 7" }
    ])
    result = chamar(resposta: resposta)

    assert_equal 1, result.atividades.size
    assert_equal "Validar 142 notas", result.atividades.first.titulo
  end

  test "no máximo 5 atividades" do
    itens = (1..8).map { |i| { "titulo" => "Atividade #{i}", "evidencia" => "Turno #{i}" } }
    assert_equal 5, chamar(resposta: conteudo("atividades" => itens)).atividades.size
  end

  test "resposta não-JSON vira resultado vazio controlado (sem explodir)" do
    result = chamar(resposta: "isto não é json")
    assert result.falhou?
    assert_empty result.atividades
  end

  test "JSON que não é objeto vira resultado vazio controlado" do
    result = chamar(resposta: conteudo([ 1, 2, 3 ]))
    assert result.falhou?
    assert_empty result.atividades
  end

  test "erro do client NÃO explode: vira resultado de falha" do
    result = Ai::SuggestConversationActivities.call(
      conversation: @conversation, client: ClienteFake.new(erro: "Ollama indisponível"), context_builder: contexto_ok
    )
    assert result.falhou?
    assert_equal "Ollama indisponível", result.erro
  end

  test "sem contexto textual: NÃO chama a IA e retorna sem_contexto" do
    result = Ai::SuggestConversationActivities.call(
      conversation: @conversation, client: ClienteProibido.new, context_builder: ContextoFake.new(text: "")
    )
    assert result.sem_contexto?
    assert_not result.sucesso?
    assert_empty result.atividades
    assert_not result.contexto_indisponivel?, "texto vazio do builder é :sem_texto, não :indisponivel"
  end

  test "índice indisponível: NÃO chama a IA e sinaliza contexto_indisponivel (p/ a UI)" do
    indisponivel = Class.new do
      def call(conversation:)
        Ai::ConversationContextBuilder::Result.new(text: "", status: :indisponivel, turns_used: 0)
      end
    end.new
    result = Ai::SuggestConversationActivities.call(
      conversation: @conversation, client: ClienteProibido.new, context_builder: indisponivel
    )
    assert result.sem_contexto?
    assert result.contexto_indisponivel?
  end

  test "não grava nada: sem ConversationActivityDraft, Task, TimeEntry nem ConversationLink" do
    resposta = conteudo("atividades" => [ { "titulo" => "Validar notas", "evidencia" => "Turno 7", "confianca" => "media" } ])
    assert_no_difference [ "ConversationActivityDraft.count", "Task.count", "TimeEntry.count", "ConversationLink.count" ] do
      chamar(resposta: resposta)
    end
  end

  # ── Auditoria do prompt enviado ──────────────────────────────────────────────
  def prompt_enviado(contexto_texto = "Turno 7 — usuário: validei 142 notas fiscais")
    fake = ClienteFake.new(resposta: conteudo("atividades" => []))
    Ai::SuggestConversationActivities.call(
      conversation: @conversation, client: fake, context_builder: contexto_ok(contexto_texto)
    )
    fake.messages.map { |m| m[:content] }.join("\n")
  end

  test "prompt usa os TRECHOS reais da conversa como fonte principal" do
    texto = prompt_enviado("Turno 12 — usuário: gerar relatório de XMLs")
    assert_match(/Trechos da conversa \(fonte principal\)/i, texto)
    assert_match(/Turno 12 — usuário: gerar relatório de XMLs/, texto)
    assert_match(/NÃO use apenas metadados/i, texto)
  end

  test "prompt proíbe Task formal, TimeEntry/duração e atividades meta" do
    texto = prompt_enviado
    assert_match(/NÃO é Task formal/i, texto)
    assert_match(/NÃO é TimeEntry/i, texto)
    assert_match(/NÃO estime duração/i, texto)
    assert_match(/analisar a conversa.*auditar a comunicação/i, texto)
  end

  test "prompt exige evidência e orienta lista vazia sem evidência" do
    texto = prompt_enviado
    assert_match(/CITAR uma evidência curta retirada dos trechos/i, texto)
    assert_match(/retorne a lista de atividades VAZIA/i, texto)
    assert_match(/Não invente atividades/i, texto)
  end

  test "envia format json ao client" do
    fake = ClienteFake.new(resposta: conteudo("atividades" => []))
    Ai::SuggestConversationActivities.call(conversation: @conversation, client: fake, context_builder: contexto_ok)
    assert_equal "json", fake.format
  end
end
