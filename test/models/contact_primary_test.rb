require "test_helper"

# PB-006 — regra de ≤1 contato principal por cliente.
class ContactPrimaryTest < ActiveSupport::TestCase
  setup do
    @acme = Client.create!(name: "ACME")
    @globex = Client.create!(name: "Globex")
  end

  test "marcar novo principal desmarca o principal anterior do mesmo cliente" do
    a = @acme.contacts.create!(name: "A", email: "a@x.com", is_primary: true)
    b = @acme.contacts.create!(name: "B", email: "b@x.com", is_primary: true)
    assert_not a.reload.is_primary, "anterior deve ser desmarcado"
    assert b.reload.is_primary
    assert_equal 1, @acme.contacts.where(is_primary: true).count
  end

  test "promover contato existente a principal desmarca o anterior" do
    a = @acme.contacts.create!(name: "A", email: "a@x.com", is_primary: true)
    b = @acme.contacts.create!(name: "B", email: "b@x.com", is_primary: false)
    b.update!(is_primary: true)
    assert_not a.reload.is_primary
    assert b.reload.is_primary
  end

  test "isolamento: principal de outro cliente não é afetado" do
    a = @acme.contacts.create!(name: "A", email: "a@x.com", is_primary: true)
    g = @globex.contacts.create!(name: "G", email: "g@x.com", is_primary: true)
    @acme.contacts.create!(name: "A2", email: "a2@x.com", is_primary: true)
    assert g.reload.is_primary, "principal de outro cliente permanece"
    assert_not a.reload.is_primary
  end

  test "constraint do banco barra dois principais no mesmo cliente (concorrência)" do
    @acme.contacts.create!(name: "A", email: "a@x.com", is_primary: true)
    # contorna o callback (insert direto) p/ provar a barreira do índice único parcial
    assert_raises(ActiveRecord::RecordNotUnique) do
      @acme.contacts.create!(name: "B", email: "b@x.com").update_column(:is_primary, true)
    end
  end

  test "excluir o principal pode deixar o cliente temporariamente sem principal" do
    p = @acme.contacts.create!(name: "P", email: "p@x.com", is_primary: true)
    @acme.contacts.create!(name: "S", email: "s@x.com", is_primary: false)
    p.destroy
    assert_equal 0, @acme.contacts.where(is_primary: true).count
  end
end
