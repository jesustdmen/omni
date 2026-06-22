require "test_helper"

# PB-013b — testa o sanitizador central de `return_to` isoladamente (unit).
# Uma classe dummy inclui o concern e expõe `params` controlados.
class ReturnNavigationTest < ActiveSupport::TestCase
  class Dummy
    include ReturnNavigation
    attr_accessor :params
    def initialize(params = {}) = (@params = params)
  end

  def san(value)
    # `return_to_param` é público; usa params[:return_to].
    Dummy.new(return_to: value).return_to_param
  end

  # --- aceita paths internos --------------------------------------------------

  test "aceita path interno simples" do
    assert_equal "/tasks", san("/tasks")
  end

  test "preserva query string" do
    assert_equal "/tasks?q=relatorio&status=in_progress&page=2",
                 san("/tasks?q=relatorio&status=in_progress&page=2")
  end

  test "preserva fragmento interno" do
    assert_equal "/tasks/uuid#tab-time", san("/tasks/uuid#tab-time")
  end

  test "aceita path com aba + cliente (contatos)" do
    assert_equal "/clients?tab=contacts&client_id=abc", san("/clients?tab=contacts&client_id=abc")
  end

  test "aceita a própria busca" do
    assert_equal "/search?q=acme", san("/search?q=acme")
  end

  # --- rejeita externos / malformados ----------------------------------------

  test "rejeita http externo" do
    assert_nil san("http://evil.example/tasks")
  end

  test "rejeita https externo" do
    assert_nil san("https://evil.example.org/tasks")
  end

  test "rejeita //host (protocolo-relativo)" do
    assert_nil san("//evil.example")
  end

  test "rejeita javascript: scheme" do
    assert_nil san("javascript:alert(1)")
  end

  test "rejeita backslash (ex.: /\\evil)" do
    assert_nil san("/\\evil.example")
  end

  test "rejeita CR/LF (header/log injection)" do
    assert_nil san("/tasks\r\nSet-Cookie: x=1")
    assert_nil san("/tasks\nfoo")
  end

  test "rejeita caracteres de controle" do
    assert_nil san("/tasks\x00")
    assert_nil san("/tasks\t/x")
  end

  test "rejeita valor que não começa com /" do
    assert_nil san("tasks")
    assert_nil san("evil.example/tasks")
  end

  test "rejeita vazio/nil" do
    assert_nil san(nil)
    assert_nil san("")
    assert_nil san("   ")
  end

  test "rejeita tamanho excessivo" do
    assert_nil san("/#{'a' * 3000}")
  end

  test "rejeita backslash-host disfarçado de path" do
    # "/\\/evil.example" — backslash é bloqueado antes do parse.
    assert_nil san("/\\/evil.example")
  end

  # --- safe_return_to: fallback por recurso ----------------------------------

  test "safe_return_to usa o path quando válido" do
    d = Dummy.new(return_to: "/tasks?page=2")
    assert_equal "/tasks?page=2", d.safe_return_to(fallback: "/tasks")
  end

  test "safe_return_to cai no fallback quando inválido" do
    d = Dummy.new(return_to: "https://evil.example")
    assert_equal "/tasks", d.safe_return_to(fallback: "/tasks")
  end

  test "safe_return_to cai no fallback quando ausente" do
    d = Dummy.new({})
    assert_equal "/demands", d.safe_return_to(fallback: "/demands")
  end

  test "safe_return_to com current evita loop (anti-self)" do
    d = Dummy.new(return_to: "/search?q=x")
    # se o destino é a própria página atual, usa fallback
    assert_equal "/root", d.safe_return_to(fallback: "/root", current: "/search?q=x")
  end
end
