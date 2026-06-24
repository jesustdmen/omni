# Seeds idempotentes (executáveis em qualquer ambiente).
#
# F7.1 / PB-017 — admin inicial OPT-IN por ENV (readiness de produção + Auth/Admin
# seguro single-user). A credencial de LOGIN do Admin vive no User (hash bcrypt);
# é informada por ENV apenas no momento do seed — sem senha padrão, sem senha
# hardcoded, senha NUNCA aparece em log. (A credencial de SMTP é separada: fica em
# ENV/credentials de produção, nunca no banco de usuário nem no código.)
# Sem a flag, é no-op seguro (mantém `db:seed:replant` do CI verde).
# Comportamento de idempotência:
#   - busca por e-mail; se não existe, cria com role "admin";
#   - se já existe, NÃO duplica e NÃO sobrescreve a senha; apenas promove a admin
#     quando ainda não for;
#   - colisão de username falha de forma explícita (resolver com OMNI_ADMIN_USERNAME).
# ENV: OMNI_SEED_ADMIN, OMNI_ADMIN_EMAIL, OMNI_ADMIN_PASSWORD, OMNI_ADMIN_USERNAME.

if ActiveModel::Type::Boolean.new.cast(ENV["OMNI_SEED_ADMIN"])
  email    = ENV["OMNI_ADMIN_EMAIL"].to_s.strip
  password = ENV["OMNI_ADMIN_PASSWORD"].to_s
  username = ENV.fetch("OMNI_ADMIN_USERNAME", "admin").to_s.strip

  if email.blank? || password.blank?
    raise "OMNI_SEED_ADMIN ativo: defina OMNI_ADMIN_EMAIL e OMNI_ADMIN_PASSWORD (nenhum usuário foi criado)."
  end

  admin = User.find_or_initialize_by(email: email)

  if admin.persisted?
    admin.update!(role: "admin") unless admin.admin? # promove; NÃO troca a senha
    Rails.logger.info("[seed] admin já existente garantido (role=admin) para #{email}")
  else
    admin.assign_attributes(username: username, password: password, role: "admin")
    admin.save! # senha nunca é logada
    Rails.logger.info("[seed] admin criado para #{email}")
  end
else
  Rails.logger.info("[seed] OMNI_SEED_ADMIN não ativo — nenhum admin criado (no-op).")
end
