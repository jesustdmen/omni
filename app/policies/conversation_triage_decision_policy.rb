# ADR-014: domínio compartilhado no MVP. PB-020 — decisão humana de triagem.
class ConversationTriageDecisionPolicy < ApplicationPolicy
  def update?
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
