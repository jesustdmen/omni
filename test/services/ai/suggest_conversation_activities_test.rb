require "test_helper"

# IA local (Ollama) — serviço de sugestão de atividades. Testado com um CLIENT FAKE
# (sem rede, sem Ollama). Nesta fatia o serviço só propõe em memória: não grava nada.
class Ai::SuggestConversationActivitiesTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(
      thread_id: "t-#{SecureRandom.hex(4)}", title: "Balanço de estoque",
      workspace_hash: "ws-abc", first_ts: Time.utc(2026, 6, 10, 9), last_ts: Time.utc(2026, 6, 10, 12),
      message_count: 40, user_turns: 20, assistant_turns: 20, tool_calls: 5
    )
  end

  # Client fake: devolve um texto fixo (como faria message.content) ou simula erro.
  class ClienteFake
    def initialize(resposta: nil, erro: nil)
      @resposta = resposta
      @erro = erro
    end

    def chat(messages:, model: nil, options: {}, format: nil)
      raise Ai::OllamaClient::Error, @erro if @erro

      @resposta
    end
  end

  def conteudo(hash)
    JSON.generate(hash)
  end

  test "parseia JSON válido em objetivo e atividades" do
    resposta = conteudo(
      "objetivo_principal" => "Entregar balanço auditado",
      "atividades" => [
        { "titulo" => "Validar notas", "descricao" => "142 NFs", "evidencia" => "turnos 1-10", "confianca" => "alta" }
      ]
    )
    result = Ai::SuggestConversationActivities.call(conversation: @conversation, client: ClienteFake.new(resposta: resposta))

    assert result.sucesso?
    assert_equal "Entregar balanço auditado", result.objetivo_principal
    assert_equal 1, result.atividades.size
    atividade = result.atividades.first
    assert_equal "Validar notas", atividade.titulo
    assert_equal "142 NFs", atividade.descricao
    assert_equal "alta", atividade.confianca
  end

  test "confiança inválida é normalizada para o padrão (media)" do
    resposta = conteudo(
      "objetivo_principal" => "X",
      "atividades" => [ { "titulo" => "A", "confianca" => "duvidosa" } ]
    )
    result = Ai::SuggestConversationActivities.call(conversation: @conversation, client: ClienteFake.new(resposta: resposta))

    assert_equal "media", result.atividades.first.confianca
  end

  test "confiança ausente também vira o padrão (media)" do
    resposta = conteudo("atividades" => [ { "titulo" => "A" } ])
    result = Ai::SuggestConversationActivities.call(conversation: @conversation, client: ClienteFake.new(resposta: resposta))

    assert_equal "media", result.atividades.first.confianca
  end

  test "atividade sem título é descartada" do
    resposta = conteudo("atividades" => [ { "titulo" => "  " }, { "titulo" => "Válida" } ])
    result = Ai::SuggestConversationActivities.call(conversation: @conversation, client: ClienteFake.new(resposta: resposta))

    assert_equal 1, result.atividades.size
    assert_equal "Válida", result.atividades.first.titulo
  end

  test "no máximo 5 atividades" do
    itens = (1..8).map { |i| { "titulo" => "Atividade #{i}" } }
    result = Ai::SuggestConversationActivities.call(conversation: @conversation, client: ClienteFake.new(resposta: conteudo("atividades" => itens)))

    assert_equal 5, result.atividades.size
  end

  test "resposta não-JSON vira resultado vazio controlado (sem explodir)" do
    result = Ai::SuggestConversationActivities.call(conversation: @conversation, client: ClienteFake.new(resposta: "isto não é json"))

    assert result.falhou?
    assert_empty result.atividades
    assert result.erro.present?
  end

  test "JSON que não é objeto vira resultado vazio controlado" do
    result = Ai::SuggestConversationActivities.call(conversation: @conversation, client: ClienteFake.new(resposta: conteudo([ 1, 2, 3 ])))

    assert result.falhou?
    assert_empty result.atividades
  end

  test "erro do client NÃO explode: vira resultado de falha" do
    result = Ai::SuggestConversationActivities.call(conversation: @conversation, client: ClienteFake.new(erro: "Ollama indisponível"))

    assert result.falhou?
    assert_empty result.atividades
    assert_equal "Ollama indisponível", result.erro
  end

  test "não grava nada: sem ConversationActivityDraft, Task, TimeEntry nem ConversationLink" do
    resposta = conteudo("objetivo_principal" => "X", "atividades" => [ { "titulo" => "A", "confianca" => "media" } ])
    assert_no_difference [ "ConversationActivityDraft.count", "Task.count", "TimeEntry.count", "ConversationLink.count" ] do
      Ai::SuggestConversationActivities.call(conversation: @conversation, client: ClienteFake.new(resposta: resposta))
    end
  end
end
