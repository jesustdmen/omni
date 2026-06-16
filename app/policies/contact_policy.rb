# ADR-014: domínio de trabalho compartilhado no MVP — qualquer usuário autenticado opera.
class ContactPolicy < ApplicationPolicy
  def show?
    user.present?
  end

  def create?
    user.present?
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
