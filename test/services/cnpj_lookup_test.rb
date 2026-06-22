require "test_helper"

# PB-006 — proxy de consulta de CNPJ (BrasilAPI) no servidor. Sem rede real: o
# Net::HTTP.start é substituído por um stub controlado.
class CnpjLookupTest < ActiveSupport::TestCase
  # Substitui Net::HTTP.start; o bloco recebe um "http" falso que devolve `response`
  # (ou levanta `error`). Restaura ao fim.
  def with_http(response: nil, error: nil)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) do |*_args, **_kw, &blk|
      raise error if error

      fake = Object.new
      fake.define_singleton_method(:request) { |_req| response }
      blk.call(fake)
    end
    yield
  ensure
    Net::HTTP.singleton_class.send(:remove_method, :start)
    Net::HTTP.define_singleton_method(:start, original)
  end

  def http_ok(body)
    r = Net::HTTPOK.new("1.1", "200", "OK")
    r.define_singleton_method(:body) { body }
    r
  end

  test "CNPJ inválido (≠14 dígitos) não chama a rede e falha com 422" do
    result = Cnpj::Lookup.call("123")
    assert_not result.ok
    assert_equal :unprocessable_entity, result.status
    assert_match(/14 d/i, result.error)
  end

  test "sucesso mapeia razao_social/nome_fantasia/telefone/endereço" do
    body = {
      "razao_social" => "Acme Ltda", "nome_fantasia" => "Acme",
      "ddd_telefone_1" => "1133334444", "logradouro" => "Rua X", "numero" => "10",
      "bairro" => "Centro", "municipio" => "São Paulo", "uf" => "SP", "cep" => "01000-000"
    }.to_json
    result = with_http(response: http_ok(body)) { Cnpj::Lookup.call("12.345.678/0001-99") }
    assert result.ok
    assert_equal "12345678000199", result.data[:cnpj]
    assert_equal "ACME LTDA", result.data[:name]
    assert_equal "ACME", result.data[:trade_name]
    assert_equal "1133334444", result.data[:phone]
    assert_match(/RUA X, 10/, result.data[:address])
    assert_match(%r{SÃO PAULO/SP}, result.data[:address])
  end

  test "404 → não encontrado" do
    result = with_http(response: Net::HTTPNotFound.new("1.1", "404", "Not Found")) do
      Cnpj::Lookup.call("12345678000199")
    end
    assert_not result.ok
    assert_equal :not_found, result.status
  end

  test "429 → rate-limit com mensagem clara (não 'indisponível')" do
    result = with_http(response: Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")) do
      Cnpj::Lookup.call("52005934000110")
    end
    assert_not result.ok
    assert_equal :too_many_requests, result.status
    assert_match(/limite de consultas/i, result.error)
    assert_no_match(/indispon/i, result.error)
  end

  test "timeout → falha graciosa (não levanta)" do
    result = with_http(error: Net::OpenTimeout.new) { Cnpj::Lookup.call("12345678000199") }
    assert_not result.ok
    assert_equal :gateway_timeout, result.status
  end

  test "host é fixo (allowlist) — nunca vem do usuário" do
    assert_equal "brasilapi.com.br", Cnpj::Lookup::HOST
  end
end
