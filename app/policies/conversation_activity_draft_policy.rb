# ADR-014: domínio compartilhado no MVP. PB-020 — atividades (rascunhos) da conversa.
# Itens são sempre buscados pelo escopo da conversa da URL (ver controller).
class ConversationActivityDraftPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  # Sugerir atividades com IA local é uma ação manual de criação de rascunhos.
  def suggest?
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
