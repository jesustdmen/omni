require "test_helper"
require "net/http"
require "json"

# IA local (Ollama) — cliente isolado. Testado SEM rede real: injeta-se um
# transporte (callable) que devolve [status, corpo] ou simula falha. Nenhum teste
# depende do Ollama rodando.
class Ai::OllamaClientTest < ActiveSupport::TestCase
  # Envelope nativo do /api/chat com o texto em message.content.
  def envelope(content)
    JSON.generate({ "model" => "gemma4:latest", "message" => { "role" => "assistant", "content" => content }, "done" => true })
  end

  # Transporte que sempre devolve [status, corpo] fixos.
  def transporte(status: 200, corpo: nil)
    ->(uri:, body:) { [ status, corpo ] }
  end

  # Define variáveis de ambiente só durante o bloco (restaura ao fim).
  def com_env(vars)
    originais = {}
    vars.each { |k, v| originais[k] = ENV[k]; ENV[k] = v }
    yield
  ensure
    originais.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "sucesso: extrai o texto de message.content" do
    client = Ai::OllamaClient.new(transport: transporte(corpo: envelope("Resposta da IA")))
    texto = client.chat(messages: [ { role: "user", content: "oi" } ])
    assert_equal "Resposta da IA", texto
  end

  test "usa OMNI_OLLAMA_URL na URL do endpoint /api/chat" do
    com_env("OMNI_OLLAMA_URL" => "http://example.test:9999") do
      capturado = {}
      transport = ->(uri:, body:) { capturado[:uri] = uri; [ 200, envelope("ok") ] }
      Ai::OllamaClient.new(transport: transport).chat(messages: [ { role: "user", content: "oi" } ])
      assert_equal "example.test", capturado[:uri].host
      assert_equal 9999, capturado[:uri].port
      assert_equal "/api/chat", capturado[:uri].path
    end
  end

  test "usa OMNI_OLLAMA_MODEL no corpo, com stream false" do
    com_env("OMNI_OLLAMA_MODEL" => "gemma4:teste") do
      capturado = {}
      transport = ->(uri:, body:) { capturado[:body] = body; [ 200, envelope("ok") ] }
      Ai::OllamaClient.new(transport: transport).chat(messages: [ { role: "user", content: "oi" } ])
      corpo = JSON.parse(capturado[:body])
      assert_equal "gemma4:teste", corpo["model"]
      assert_equal false, corpo["stream"]
    end
  end

  test "default de modelo é gemma4:latest quando não há ENV" do
    com_env("OMNI_OLLAMA_MODEL" => nil) do
      capturado = {}
      transport = ->(uri:, body:) { capturado[:body] = body; [ 200, envelope("ok") ] }
      Ai::OllamaClient.new(transport: transport).chat(messages: [ { role: "user", content: "oi" } ])
      assert_equal "gemma4:latest", JSON.parse(capturado[:body])["model"]
    end
  end

  test "format e options são enviados quando informados" do
    capturado = {}
    transport = ->(uri:, body:) { capturado[:body] = body; [ 200, envelope("ok") ] }
    Ai::OllamaClient.new(transport: transport).chat(
      messages: [ { role: "user", content: "oi" } ], format: "json", options: { temperature: 0.2 }
    )
    corpo = JSON.parse(capturado[:body])
    assert_equal "json", corpo["format"]
    assert_equal 0.2, corpo["options"]["temperature"]
  end

  test "HTTP fora de 2xx vira erro tipado" do
    client = Ai::OllamaClient.new(transport: transporte(status: 500, corpo: "erro interno"))
    assert_raises(Ai::OllamaClient::Error) do
      client.chat(messages: [ { role: "user", content: "oi" } ])
    end
  end

  test "JSON inválido na resposta vira erro tipado" do
    client = Ai::OllamaClient.new(transport: transporte(corpo: "isto não é json"))
    assert_raises(Ai::OllamaClient::Error) do
      client.chat(messages: [ { role: "user", content: "oi" } ])
    end
  end

  test "resposta sem message.content vira erro tipado" do
    client = Ai::OllamaClient.new(transport: transporte(corpo: JSON.generate({ "done" => true })))
    assert_raises(Ai::OllamaClient::Error) do
      client.chat(messages: [ { role: "user", content: "oi" } ])
    end
  end

  test "timeout de conexão vira erro tipado" do
    transport = ->(uri:, body:) { raise Net::OpenTimeout }
    client = Ai::OllamaClient.new(transport: transport)
    assert_raises(Ai::OllamaClient::Error) do
      client.chat(messages: [ { role: "user", content: "oi" } ])
    end
  end

  test "conexão recusada vira erro tipado" do
    transport = ->(uri:, body:) { raise Errno::ECONNREFUSED }
    client = Ai::OllamaClient.new(transport: transport)
    assert_raises(Ai::OllamaClient::Error) do
      client.chat(messages: [ { role: "user", content: "oi" } ])
    end
  end
end
