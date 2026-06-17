# ADR-014: domínio compartilhado no MVP. F3.UI.1 — console SOMENTE LEITURA.
class SyncRunPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
