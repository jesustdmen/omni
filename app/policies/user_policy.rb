# Policy de exemplo da Fundação (ADR-004). Domínio real ganha policies na Fase 2+.
class UserPolicy < ApplicationPolicy
  def show?
    user.present? && (user.admin? || record == user)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.where(id: user&.id)
    end
  end
end
