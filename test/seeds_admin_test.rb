require "test_helper"

# F7.1 — seed admin opt-in/idempotente. Usa Rails.application.load_seed no DB de
# teste (dentro da transação do teste → rollback automático). Não vaza segredo.
class SeedsAdminTest < ActiveSupport::TestCase
  def with_env(vars)
    saved = {}
    vars.each do |key, value|
      saved[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    saved.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  def load_seed
    Rails.application.load_seed
  end

  test "sem OMNI_SEED_ADMIN: no-op, não cria usuário e não falha" do
    with_env("OMNI_SEED_ADMIN" => nil) do
      assert_no_difference("User.count") { load_seed }
    end
  end

  test "flag ativa sem e-mail/senha: erro claro e nenhum usuário criado" do
    with_env("OMNI_SEED_ADMIN" => "true", "OMNI_ADMIN_EMAIL" => nil, "OMNI_ADMIN_PASSWORD" => nil) do
      assert_no_difference("User.count") do
        assert_raises(RuntimeError) { load_seed }
      end
    end
  end

  test "ENV válida cria admin com senha válida, username e role admin" do
    with_env("OMNI_SEED_ADMIN" => "true", "OMNI_ADMIN_EMAIL" => "boss@omni.local",
             "OMNI_ADMIN_PASSWORD" => "s3nh4-forte-xyz", "OMNI_ADMIN_USERNAME" => "boss") do
      assert_difference("User.count", 1) { load_seed }
      user = User.find_by(email: "boss@omni.local")
      assert_equal "boss", user.username
      assert_equal "admin", user.role
      assert user.valid_password?("s3nh4-forte-xyz")
    end
  end

  test "idempotente: rodar duas vezes cria apenas um usuário" do
    env = { "OMNI_SEED_ADMIN" => "true", "OMNI_ADMIN_EMAIL" => "boss@omni.local",
            "OMNI_ADMIN_PASSWORD" => "s3nh4-forte-xyz", "OMNI_ADMIN_USERNAME" => "boss" }
    with_env(env) do
      load_seed
      assert_no_difference("User.count") { load_seed }
      assert_equal 1, User.where(email: "boss@omni.local").count
    end
  end

  test "usuário existente é promovido a admin sem trocar a senha nem o username" do
    User.create!(username: "ja", email: "ja@omni.local", password: "orig-pass-123", role: "user")
    with_env("OMNI_SEED_ADMIN" => "true", "OMNI_ADMIN_EMAIL" => "ja@omni.local",
             "OMNI_ADMIN_PASSWORD" => "NOVA-senha-999", "OMNI_ADMIN_USERNAME" => "outro") do
      assert_no_difference("User.count") { load_seed }
    end
    user = User.find_by(email: "ja@omni.local")
    assert user.admin?, "deve ter sido promovido a admin"
    assert user.valid_password?("orig-pass-123"), "senha original deve permanecer"
    assert_not user.valid_password?("NOVA-senha-999"), "seed não deve aplicar nova senha"
    assert_equal "ja", user.username, "username não deve ser sobrescrito"
  end
end
