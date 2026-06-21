# PB-007 — fecha os status de projeto no banco (planning/in_progress/completed/on_hold).
# Aditiva: só adiciona CHECK; não altera/remove dados. Validação prévia (ETAPA ZERO)
# confirmou que os status existentes são todos válidos (apenas "planning" no dev).
class AddStatusCheckToProjects < ActiveRecord::Migration[8.1]
  def up
    # Guarda: aborta se houver algum status fora da lista (não corrige silenciosamente).
    invalid = exec_query(
      "SELECT DISTINCT status FROM projects WHERE status NOT IN ('planning','in_progress','completed','on_hold')"
    ).rows.flatten
    raise "Status de projeto inválidos no banco: #{invalid.inspect}. Corrija antes de aplicar o CHECK." if invalid.any?

    add_check_constraint :projects,
      "status IN ('planning','in_progress','completed','on_hold')",
      name: "projects_status_check"
  end

  def down
    remove_check_constraint :projects, name: "projects_status_check"
  end
end
