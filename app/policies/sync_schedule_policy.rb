# PB-016a — ADR-014: domínio compartilhado no MVP (qualquer usuário autenticado).
# Configurar o agendamento da sincronização é ação operacional; mesma regra.
class SyncSchedulePolicy < ApplicationPolicy
  def update?
    user.present?
  end
end
