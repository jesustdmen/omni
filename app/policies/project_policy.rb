# ADR-014: domínio de trabalho compartilhado no MVP — qualquer usuário autenticado opera.
class ProjectPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user.present?
  end

  # PB-007 — duplicar é uma criação (mesma regra). `set_project` autoriza por nome
  # da action (duplicate?) antes de o controller chamar create? explicitamente.
  def duplicate?
    create?
  end

  def new?
    create?
  end

  def update?
    user.present?
  end

  def edit?
    update?
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
