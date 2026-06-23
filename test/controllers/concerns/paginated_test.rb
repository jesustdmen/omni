require "test_helper"

# Concern de paginação: allowlist de tamanho + "Mostrar tudo" (com teto).
class PaginatedTest < ActiveSupport::TestCase
  # Dummy que inclui o concern e expõe params controlados.
  class Dummy
    include Paginated
    attr_accessor :params
    def initialize(params = {}) = (@params = params)
  end

  def with_params(p) = Dummy.new(p)

  test "valor da allowlist é respeitado" do
    assert_equal 10, with_params(per_page: "10").sanitized_per_page
    assert_equal 100, with_params(per_page: "100").sanitized_per_page
  end

  test "valor inválido cai no default (50)" do
    assert_equal 50, with_params(per_page: "999").sanitized_per_page
    assert_equal 50, with_params(per_page: "abc").sanitized_per_page
    assert_equal 50, with_params({}).sanitized_per_page
  end

  test "'all' → teto (ALL_CAP) e show_all_per_page? verdadeiro" do
    d = with_params(per_page: "all")
    assert d.show_all_per_page?
    assert_equal Paginated::ALL_CAP, d.sanitized_per_page
  end

  test "não-'all' → show_all_per_page? falso" do
    assert_not with_params(per_page: "50").show_all_per_page?
    assert_not with_params({}).show_all_per_page?
  end

  test "select inclui as opções fixas + 'Mostrar tudo'" do
    opts = with_params({}).per_page_select_options
    assert_includes opts, [ "10/página", 10 ]
    assert_includes opts, [ "100/página", 100 ]
    assert_includes opts, [ "Mostrar tudo", "all" ]
  end

  test "per_page_selected reflete a escolha (inclui 'all')" do
    assert_equal 25, with_params(per_page: "25").per_page_selected
    assert_equal "all", with_params(per_page: "all").per_page_selected
    assert_equal 50, with_params({}).per_page_selected
  end

  test "aviso de teto: só quando 'all' e total > ALL_CAP" do
    d = with_params(per_page: "all")
    assert_nil d.per_page_cap_notice(Paginated::ALL_CAP)        # no limite, sem aviso
    note = d.per_page_cap_notice(Paginated::ALL_CAP + 648)      # acima do teto
    assert_match(/Mostrando os primeiros #{Paginated::ALL_CAP}/, note)
    assert_match(/#{Paginated::ALL_CAP + 648}/, note)
    # sem "all", nunca avisa
    assert_nil with_params(per_page: "50").per_page_cap_notice(99_999)
  end
end
