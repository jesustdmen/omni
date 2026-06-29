# ADR-014: domínio compartilhado no MVP. PB-020d — blocos de trabalho (rascunhos) da conversa.
# Itens são sempre buscados pelo escopo da conversa da URL (ver controller).
class ConversationWorkBlockPolicy < ApplicationPolicy
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
