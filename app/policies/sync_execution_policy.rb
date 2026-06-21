# PB-015 — ADR-014: domínio compartilhado no MVP (qualquer usuário autenticado).
# Disparar a sincronização operacional é ação de escrita; segue a mesma regra.
class SyncExecutionPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
