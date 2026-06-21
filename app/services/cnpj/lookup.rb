require "net/http"
require "json"
require "uri"

module Cnpj
  # PB-006 — consulta de CNPJ na BrasilAPI feita pelo SERVIDOR (proxy), com:
  #  - HOST fixo allowlisted (nunca aceita URL do usuário; só os 14 dígitos);
  #  - timeout curto; falha graciosa (não derruba o request);
  #  - sem persistir a resposta crua; devolve só os campos usados pelo form.
  # Espelha o autopreenchimento do RepoA (razao_social/nome_fantasia/telefone/endereço).
  class Lookup
    HOST = "brasilapi.com.br".freeze
    PATH = "/api/cnpj/v1/".freeze
    TIMEOUT = 5 # segundos (abertura + leitura)

    Result = Struct.new(:ok, :data, :error, :status, keyword_init: true)

    def self.call(raw_cnpj)
      new(raw_cnpj).call
    end

    def initialize(raw_cnpj)
      @digits = Client.normalize_cnpj_digits(raw_cnpj)
    end

    def call
      return failure("CNPJ deve ter 14 dígitos.", :unprocessable_entity) unless @digits.length == 14

      uri = URI::HTTPS.build(host: HOST, path: "#{PATH}#{@digits}") # host fixo; só dígitos validados
      response = get(uri)

      case response
      when Net::HTTPSuccess
        Result.new(ok: true, data: map_fields(JSON.parse(response.body)), error: nil, status: :ok)
      when Net::HTTPNotFound
        failure("CNPJ não encontrado.", :not_found)
      else
        failure("Serviço de CNPJ indisponível no momento.", :bad_gateway)
      end
    rescue JSON::ParserError
      failure("Resposta inválida do serviço de CNPJ.", :bad_gateway)
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
      failure("Tempo esgotado ao consultar o CNPJ.", :gateway_timeout)
    rescue StandardError
      failure("Não foi possível consultar o CNPJ.", :bad_gateway)
    end

    private

    def failure(message, status)
      Result.new(ok: false, data: nil, error: message, status: status)
    end

    def get(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
    end

    # Só os campos que o form usa; nada além é exposto/persistido.
    def map_fields(json)
      {
        cnpj: @digits,
        name: json["razao_social"].to_s.upcase.presence,
        trade_name: json["nome_fantasia"].to_s.upcase.presence,
        phone: json["ddd_telefone_1"].presence,
        address: build_address(json)
      }.compact
    end

    def build_address(json)
      parts = [
        [ json["logradouro"], json["numero"] ].compact_blank.join(", "),
        json["bairro"],
        [ json["municipio"], json["uf"] ].compact_blank.join("/"),
        (json["cep"].present? ? "CEP: #{json['cep']}" : nil)
      ].compact_blank
      parts.join(" - ").upcase.presence
    end
  end
end
