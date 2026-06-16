require "test_helper"

class ContactTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
  end

  test "exige client" do
    contact = Contact.new(name: "X", email: "x@example.com")
    assert_not contact.valid?
  end

  test "pertence a um cliente" do
    contact = @client.contacts.create!(name: "X", email: "x@example.com")
    assert_equal @client, contact.client
  end

  test "exige name e email" do
    assert_not @client.contacts.build(email: "x@example.com").valid?
    assert_not @client.contacts.build(name: "X").valid?
  end

  test "cascade ao excluir cliente" do
    @client.contacts.create!(name: "X", email: "x@example.com")
    assert_difference "Contact.count", -1 do
      @client.destroy
    end
  end
end
