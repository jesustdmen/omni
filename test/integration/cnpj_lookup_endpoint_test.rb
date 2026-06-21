require "test_helper"

# PB-006 — endpoint-proxy /clients/cnpj_lookup (servidor consulta CNPJ).
class CnpjLookupEndpointTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
  end

  # Substitui Cnpj::Lookup.call por um resultado fixo, restaurando ao fim.
  def with_lookup_result(result)
    original = Cnpj::Lookup.method(:call)
    Cnpj::Lookup.define_singleton_method(:call) { |*_args| result }
    yield
  ensure
    Cnpj::Lookup.singleton_class.send(:remove_method, :call)
    Cnpj::Lookup.define_singleton_method(:call, original)
  end

  test "exige autenticação" do
    sign_out @user
    get cnpj_lookup_clients_path(cnpj: "12345678000199")
    assert_redirected_to new_user_session_path
  end

  test "retorna JSON dos campos quando o serviço resolve" do
    data = { cnpj: "12345678000199", name: "ACME LTDA", trade_name: "ACME" }
    with_lookup_result(Cnpj::Lookup::Result.new(ok: true, data: data, error: nil, status: :ok)) do
      get cnpj_lookup_clients_path(cnpj: "12345678000199")
    end
    assert_response :success
    assert_equal "ACME LTDA", JSON.parse(response.body)["name"]
  end

  test "propaga erro/status do serviço (ex.: não encontrado)" do
    with_lookup_result(Cnpj::Lookup::Result.new(ok: false, data: nil, error: "CNPJ não encontrado.", status: :not_found)) do
      get cnpj_lookup_clients_path(cnpj: "00000000000000")
    end
    assert_response :not_found
    assert_match(/não encontrado/i, JSON.parse(response.body)["error"])
  end
end
