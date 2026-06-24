# PB-019a — ADR-014: domínio compartilhado no MVP (qualquer usuário autenticado).
# Admin/single-user atual enxerga e gerencia todas as empresas prestadoras.
# Sem roles novas; sem vínculo User↔Prestadora nesta fatia.
class ProviderCompanyPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def new?
    create?
  end

  def create?
    user.present?
  end

  def edit?
    update?
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
