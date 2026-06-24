require "test_helper"

# PB-019a — Empresa Prestadora (modelo + normalização/unicidade de CNPJ).
class ProviderCompanyTest < ActiveSupport::TestCase
  test "válida com nome" do
    assert ProviderCompany.new(name: "Acme Serviços LTDA").valid?
  end

  test "name é obrigatório" do
    pc = ProviderCompany.new(name: "")
    assert_not pc.valid?
    assert pc.errors[:name].any?
  end

  test "cnpj é normalizado para só dígitos" do
    pc = ProviderCompany.create!(name: "Acme", cnpj: "11.222.333/0001-44")
    assert_equal "11222333000144", pc.cnpj
  end

  test "cnpj vazio/branco vira nil" do
    assert_nil ProviderCompany.create!(name: "A", cnpj: "   ").cnpj
    assert_nil ProviderCompany.create!(name: "B", cnpj: "").cnpj
    assert_nil ProviderCompany.create!(name: "C", cnpj: nil).cnpj
  end

  test "cnpj duplicado entre prestadoras é bloqueado (com ou sem pontuação)" do
    ProviderCompany.create!(name: "Primeira", cnpj: "11222333000144")
    dup = ProviderCompany.new(name: "Segunda", cnpj: "11.222.333/0001-44")
    assert_not dup.valid?
    assert dup.errors[:cnpj].any?
  end

  test "vários prestadores sem cnpj (nil) coexistem" do
    ProviderCompany.create!(name: "Sem 1")
    assert ProviderCompany.new(name: "Sem 2").valid?
  end

  test "cnpj igual ao de um Client é permitido (domínios distintos)" do
    Client.create!(name: "Cliente X", cnpj: "11222333000144")
    pc = ProviderCompany.new(name: "Prestadora X", cnpj: "11222333000144")
    assert pc.valid?, pc.errors.full_messages.to_sentence
  end

  test "active default true; pode inativar" do
    pc = ProviderCompany.create!(name: "Ativa")
    assert pc.active?
    pc.update!(active: false)
    assert_not pc.reload.active?
  end

  test "scopes ordered e active" do
    a = ProviderCompany.create!(name: "Zeta", active: true)
    b = ProviderCompany.create!(name: "Alfa", active: false)
    assert_equal %w[Alfa Zeta], ProviderCompany.ordered.pluck(:name)
    assert_includes ProviderCompany.active, a
    assert_not_includes ProviderCompany.active, b
  end
end
