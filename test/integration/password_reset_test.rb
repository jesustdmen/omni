require "test_helper"

# PB-017 — recuperação de senha (Devise :recoverable) endurecida.
# Cobre: geração de e-mail + token; expiração do token conforme config
# (reset_password_within = 30 min); reset bem-sucedido; anti-enumeração (paranoid);
# e invalidação de sessões existentes após troca de senha.
class PasswordResetTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @user = User.create!(username: "boss", email: "boss@example.com",
                         password: "secret12345", role: "admin")
  end

  test "config: token de reset expira em 30 minutos" do
    assert_equal 30.minutes, Devise.reset_password_within
  end

  test "solicitar reset para e-mail existente envia e-mail com token" do
    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      post user_password_path, params: { user: { email: "boss@example.com" } }
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "boss@example.com" ], mail.to
    # O e-mail traz o link de edição com o token de reset.
    assert_match(/reset_password_token=/, mail.body.encoded)
  end

  test "solicitar reset para e-mail inexistente NÃO vaza existência (paranoid) e não envia e-mail" do
    assert_no_difference("ActionMailer::Base.deliveries.size") do
      post user_password_path, params: { user: { email: "naoexiste@example.com" } }
    end
    # paranoid: redireciona para o login com a mesma mensagem de sucesso aparente.
    assert_response :redirect
  end

  test "reset com token válido troca a senha e permite login com a nova" do
    raw_token = @user.send_reset_password_instructions
    put user_password_path, params: {
      user: { reset_password_token: raw_token,
              password: "nova-senha-123", password_confirmation: "nova-senha-123" }
    }
    assert_response :redirect

    @user.reload
    assert @user.valid_password?("nova-senha-123"), "nova senha deve valer"
    assert_not @user.valid_password?("secret12345"), "senha antiga não deve mais valer"
  end

  test "reset com token expirado (>30min) é rejeitado e a senha permanece" do
    raw_token = @user.send_reset_password_instructions
    # Simula a passagem do tempo além da janela de validade.
    @user.update_column(:reset_password_sent_at, 31.minutes.ago)

    put user_password_path, params: {
      user: { reset_password_token: raw_token,
              password: "nova-senha-123", password_confirmation: "nova-senha-123" }
    }
    assert_response :unprocessable_entity

    @user.reload
    assert @user.valid_password?("secret12345"), "senha original deve permanecer após token expirado"
    assert_not @user.valid_password?("nova-senha-123")
  end

  test "reset com nova senha curta (<10) é rejeitado" do
    raw_token = @user.send_reset_password_instructions
    put user_password_path, params: {
      user: { reset_password_token: raw_token,
              password: "curta1", password_confirmation: "curta1" }
    }
    assert_response :unprocessable_entity
    @user.reload
    assert @user.valid_password?("secret12345")
  end

  # Invalidação de sessões após troca de senha: a sessão do Devise é validada
  # contra o authenticatable_salt (derivado do encrypted_password). Ao trocar a
  # senha, o salt muda e sessões antigas deixam de ser válidas.
  test "trocar a senha invalida sessões existentes (salt de autenticação muda)" do
    salt_antes = @user.authenticatable_salt
    @user.send(:password=, "outra-senha-456")
    @user.save!
    @user.reload
    salt_depois = @user.authenticatable_salt

    assert_not_equal salt_antes, salt_depois,
                     "o salt de autenticação deve mudar ao trocar a senha (invalida sessões antigas)"
  end

  test "sessão ativa cai após reset de senha por outro caminho (re-login exigido)" do
    # Loga normalmente.
    post user_session_path, params: { user: { email: "boss@example.com", password: "secret12345" } }
    get root_path
    assert_response :success

    # Senha é trocada (ex.: reset por e-mail concluído em outro dispositivo).
    @user.send(:password=, "trocada-em-outro-789")
    @user.save!

    # A sessão antiga não deve mais dar acesso a área autenticada.
    get root_path
    assert_redirected_to new_user_session_path
  end
end
