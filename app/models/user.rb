class User < ApplicationRecord
  # Devise (ADR-003). :validatable cobre formato de e-mail e tamanho de senha.
  # PB-017 — uso single-user/somente-Admin: SEM cadastro público (:registerable
  # removido). Contas são criadas via seed seguro (db/seeds.rb) ou console.
  # :recoverable mantido (reset por e-mail). Sem MFA/OAuth/passkeys (fora de escopo).
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  ROLES = %w[user admin].freeze

  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end

  # ADR-003 — re-hash oportunístico: se o custo do hash armazenado divergir do
  # custo atual do Devise (ex.: base legada importada com bcrypt custo 10),
  # regrava o hash no próximo login bem-sucedido. Não bloqueia o login.
  def valid_password?(password)
    super.tap { |ok| rehash_password_if_needed(password) if ok }
  end

  private

  def rehash_password_if_needed(password)
    return if encrypted_password.blank?
    return if BCrypt::Password.new(encrypted_password).cost == Devise.stretches

    update_column(:encrypted_password, Devise::Encryptor.digest(self.class, password))
  rescue BCrypt::Errors::InvalidHash
    nil
  end
end
