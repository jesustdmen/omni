require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "exige name" do
    assert_not Client.new(name: nil).valid?
  end

  test "permite múltiplos clientes sem CNPJ" do
    Client.create!(name: "A")
    segundo = Client.new(name: "B")
    assert segundo.valid?
    assert segundo.save
  end

  test "rejeita CNPJ duplicado quando preenchido" do
    Client.create!(name: "A", cnpj: "12345678000199")
    dup = Client.new(name: "B", cnpj: "12345678000199")
    assert_not dup.valid?
    assert dup.errors[:cnpj].any?
  end

  test "normaliza CNPJ em branco para nil" do
    c = Client.create!(name: "A", cnpj: "   ")
    assert_nil c.cnpj
  end

  test "aceita workspace_paths como array" do
    c = Client.create!(name: "A", workspace_paths: [ "~/code/x", "~/code/y" ])
    assert_equal [ "~/code/x", "~/code/y" ], c.reload.workspace_paths
  end

  test "workspace_paths_text converte texto em array" do
    c = Client.create!(name: "A", workspace_paths_text: "~/code/x\n~/code/y\n")
    assert_equal [ "~/code/x", "~/code/y" ], c.reload.workspace_paths
  end
end
