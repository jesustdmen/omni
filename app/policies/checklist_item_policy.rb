# PB-004b — ADR-014: domínio compartilhado no MVP (qualquer usuário autenticado).
# Itens são sempre buscados pelo escopo da tarefa da URL (ver controller).
class ChecklistItemPolicy < ApplicationPolicy
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
