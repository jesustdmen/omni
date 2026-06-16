require "test_helper"

class ContactsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
  end

  test "new contato sob cliente renderiza" do
    get new_client_contact_path(@client)
    assert_response :success
    assert_select "form"
    assert_select "input[name=?]", "contact[email]"
  end

  test "create contato sob cliente" do
    assert_difference "@client.contacts.count", 1 do
      post client_contacts_path(@client), params: { contact: { name: "Joana", email: "joana@example.com" } }
    end
    assert_redirected_to client_path(@client)
  end

  test "create inválido mostra erro" do
    assert_no_difference "Contact.count" do
      post client_contacts_path(@client), params: { contact: { name: "", email: "" } }
    end
    assert_response :unprocessable_entity
    assert_select "div.errors"
  end

  test "contatos aparecem no contexto do cliente" do
    @client.contacts.create!(name: "Joana", email: "joana@example.com")
    get client_path(@client)
    assert_response :success
    assert_select "li", /Joana/
  end

  test "update e destroy contato" do
    contact = @client.contacts.create!(name: "Joana", email: "joana@example.com")
    patch client_contact_path(@client, contact), params: { contact: { name: "João" } }
    assert_redirected_to client_path(@client)
    assert_equal "João", contact.reload.name

    assert_difference "Contact.count", -1 do
      delete client_contact_path(@client, contact)
    end
  end
end
