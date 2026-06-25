require "net/http"
require "json"
require "uri"

module Ai
  # Cliente ISOLADO do Ollama (IA local) — fala o endpoint NATIVO `POST /api/chat`
  # e devolve o TEXTO PURO de `message.content` (ver docs/ia_local_ollama_gemma4_api.md).
  #
  # Princípios desta fatia (núcleo testável):
  #   - sem gem nova: usa Net::HTTP da stdlib;
  #   - URL base e modelo por ENV (OMNI_OLLAMA_URL / OMNI_OLLAMA_MODEL), com defaults;
  #   - NÃO devolve o envelope cru ao chamador: só o conteúdo gerado;
  #   - toda falha (conexão, timeout, HTTP != 2xx, JSON inválido, ausência de
  #     message.content) vira `Ai::OllamaClient::Error`, capturável pelo caso de uso;
  #   - o transporte HTTP é injetável (`transport:`) só como COSTURA DE TESTE — assim a
  #     suíte não depende do Ollama real nem de rede (ADR: testes determinísticos).
  #
  # Esta classe NÃO grava nada, NÃO conhece Triagem/atividades e NÃO decide nada:
  # apenas transporta a pergunta e devolve o texto. A camada de produto (sugestão)
  # é quem interpreta — e a confirmação é sempre humana.
  class OllamaClient
    # Erro tipado único: o caso de uso captura SÓ esta classe para degradar com segurança.
    class Error < StandardError; end

    DEFAULT_URL = "http://localhost:11434"
    DEFAULT_MODEL = "gemma4:latest"
    CHAT_PATH = "/api/chat"
    # Conexão curta (detecta servidor fora do ar) + leitura longa (carga fria do modelo).
    DEFAULT_OPEN_TIMEOUT = 3
    DEFAULT_READ_TIMEOUT = 120

    def initialize(base_url: nil, model: nil, open_timeout: DEFAULT_OPEN_TIMEOUT,
                   read_timeout: DEFAULT_READ_TIMEOUT, transport: nil)
      @base_url = (base_url || ENV.fetch("OMNI_OLLAMA_URL", DEFAULT_URL)).to_s
      @model = (model || ENV.fetch("OMNI_OLLAMA_MODEL", DEFAULT_MODEL)).to_s
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @transport = transport # callable(uri:, body:) -> [status_inteiro, corpo_string]
    end

    attr_reader :model

    # Envia `messages` ao /api/chat (stream desligado) e retorna o texto de
    # `message.content`. `format: "json"` pede ao modelo uma resposta JSON válida.
    def chat(messages:, model: nil, options: {}, format: nil)
      body = { model: model || @model, messages: messages, stream: false }
      body[:options] = options if options && !options.empty?
      body[:format] = format if format

      payload = post_json(CHAT_PATH, body)
      extract_content(payload)
    end

    private

    # POST com corpo JSON; valida status 2xx e desserializa a resposta.
    def post_json(path, body)
      uri = URI.parse(@base_url.chomp("/") + path)
      status, raw = perform(uri, JSON.generate(body))
      unless status.between?(200, 299)
        raise Error, "Ollama respondeu HTTP #{status}"
      end
      parse_json(raw)
    end

    # Executa o transporte (real ou injetado) e normaliza falhas de rede em Error tipado.
    def perform(uri, json_body)
      if @transport
        @transport.call(uri: uri, body: json_body)
      else
        real_perform(uri, json_body)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "Timeout ao contatar o Ollama: #{e.message}"
    rescue SystemCallError, SocketError, IOError => e
      raise Error, "Falha de conexão com o Ollama: #{e.message}"
    end

    # Transporte real (não exercido nos testes — a suíte injeta `transport`).
    def real_perform(uri, json_body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = json_body

      response = http.request(request)
      [ response.code.to_i, response.body.to_s ]
    end

    def parse_json(raw)
      JSON.parse(raw.to_s)
    rescue JSON::ParserError => e
      raise Error, "Resposta do Ollama não é JSON válido: #{e.message}"
    end

    # Só o conteúdo gerado: nunca devolve o envelope cru. Sem message.content → Error.
    def extract_content(payload)
      content = payload.is_a?(Hash) ? payload.dig("message", "content") : nil
      if content.nil? || content.to_s.strip.empty?
        raise Error, "Resposta do Ollama sem message.content"
      end
      content
    end
  end
end
