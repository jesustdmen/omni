# PB-019b — ADR-014: domínio compartilhado no MVP (qualquer usuário autenticado).
class ContractPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = user.present?
  def new? = create?
  def create? = user.present?
  def edit? = update?
  def update? = user.present?
  def destroy? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
