# PB-018 — ADR-014: domínio compartilhado no MVP (qualquer usuário autenticado).
# Administrar status configuráveis é ação operacional; mesma regra dos demais.
class ConfigurableStatusPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def update?
    user.present?
  end

  def destroy?
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
