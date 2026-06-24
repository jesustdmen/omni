# PB-018 — Status configurável para Tarefas e Projetos.
#
# Modelagem (aprovada pelo PO): a coluna `status` (string/key) é mantida em tasks e
# projects para reduzir impacto; os rótulos/cores/opções passam a vir da tabela
# `configurable_statuses`. A INTEGRIDADE fica no BANCO via FK composta
# (status_entity, status) -> configurable_statuses(entity_type, key) ON DELETE RESTRICT:
#   - garante que só existem keys válidas;
#   - garante que task aponta para status de 'task' e project para status de 'project'
#     (a coluna discriminadora `status_entity` é constante por linha, travada por CHECK);
#   - garante que um status EM USO não pode ser excluído (RESTRICT).
# Os CHECKs antigos de status (lista fixa) são REMOVIDOS de tasks/projects — eles
# travariam novas keys criadas pelo usuário. Demands ficam FIXAS (CHECK preservado).
#
# Status iniciais (seed determinístico) espelham exatamente o que existe hoje.
class CreateConfigurableStatuses < ActiveRecord::Migration[8.1]
  ENTITIES = %w[task project].freeze

  TASK_STATUSES = [
    # key,           name,            color,     position, active, final
    [ "pending",     "Pendente",      "#9CA3AF", 1, true,  false ],
    [ "todo",        "A fazer",       "#6B7280", 2, true,  false ],
    [ "in_progress", "Em andamento",  "#3B82F6", 3, true,  false ],
    [ "done",        "Concluída",     "#8B5CF6", 4, true,  true ],
    [ "canceled",    "Cancelada",     "#EF4444", 5, true,  true ]
  ].freeze

  PROJECT_STATUSES = [
    [ "planning",    "Planejamento",  "#6B7280", 1, true,  false ],
    [ "in_progress", "Em andamento",  "#3B82F6", 2, true,  false ],
    [ "completed",   "Concluído",     "#8B5CF6", 3, true,  true ],
    [ "on_hold",     "Em espera",     "#F59E0B", 4, true,  false ]
  ].freeze

  def up
    # 1) Tabela de status configuráveis.
    create_table :configurable_statuses, id: :uuid do |t|
      t.string  :entity_type, null: false # 'task' | 'project'
      t.string  :key,         null: false # snake_case ASCII (a "chave" armazenada em status)
      t.string  :name,        null: false # rótulo PT-BR exibido
      t.string  :color,       null: false # cor (hex #rrggbb, allowlist no model)
      t.integer :position,    null: false, default: 0
      t.boolean :active,      null: false, default: true
      t.boolean :final,       null: false, default: false # "finalizador" — só filtros/exibição
      t.timestamps
    end

    add_index :configurable_statuses, [ :entity_type, :key ], unique: true,
              name: "idx_configurable_statuses_entity_key"
    add_index :configurable_statuses, [ :entity_type, :position ],
              name: "idx_configurable_statuses_entity_position"
    add_check_constraint :configurable_statuses,
                         "entity_type IN ('task','project')",
                         name: "configurable_statuses_entity_type_check"
    # A FK composta exige um índice único sobre as colunas referenciadas (entity_type,key)
    # — já garantido por idx_configurable_statuses_entity_key acima.

    # 2) Seed determinístico dos status atuais (espelha enum/STATUSES existentes).
    now = Time.current
    rows = TASK_STATUSES.map { |k, n, c, p, a, f| seed_row("task", k, n, c, p, a, f, now) } +
           PROJECT_STATUSES.map { |k, n, c, p, a, f| seed_row("project", k, n, c, p, a, f, now) }
    execute <<~SQL
      INSERT INTO configurable_statuses
        (id, entity_type, key, name, color, position, active, final, created_at, updated_at)
      VALUES #{rows.join(", ")};
    SQL

    # 3) Discriminador constante por linha (viabiliza a FK composta por entidade).
    add_column :tasks,    :status_entity, :string, null: false, default: "task"
    add_column :projects, :status_entity, :string, null: false, default: "project"
    # Trava o discriminador num valor fixo (não pode "trocar de entidade").
    add_check_constraint :tasks,    "status_entity = 'task'",    name: "tasks_status_entity_check"
    add_check_constraint :projects, "status_entity = 'project'", name: "projects_status_entity_check"

    # 4) ETAPA ZERO: aborta se houver status fora do seed (FK falharia).
    %w[tasks projects].each do |table|
      entity = (table == "tasks" ? "task" : "project")
      invalid = exec_query(<<~SQL).rows.flatten
        SELECT DISTINCT t.status FROM #{table} t
        LEFT JOIN configurable_statuses cs
          ON cs.entity_type = '#{entity}' AND cs.key = t.status
        WHERE cs.id IS NULL
      SQL
      raise "#{table}: status sem correspondente em configurable_statuses: #{invalid.inspect}. Corrija antes da FK." if invalid.any?
    end

    # 5) Remove os CHECKs de lista fixa (substituídos pela FK composta).
    remove_check_constraint :tasks,    name: "tasks_status_check"
    remove_check_constraint :projects, name: "projects_status_check"

    # 6) FK composta com ON DELETE RESTRICT (garante integridade + bloqueio de exclusão).
    execute <<~SQL
      ALTER TABLE tasks
        ADD CONSTRAINT fk_tasks_status
        FOREIGN KEY (status_entity, status)
        REFERENCES configurable_statuses (entity_type, key)
        ON DELETE RESTRICT ON UPDATE CASCADE;
    SQL
    execute <<~SQL
      ALTER TABLE projects
        ADD CONSTRAINT fk_projects_status
        FOREIGN KEY (status_entity, status)
        REFERENCES configurable_statuses (entity_type, key)
        ON DELETE RESTRICT ON UPDATE CASCADE;
    SQL
  end

  def down
    execute "ALTER TABLE tasks    DROP CONSTRAINT IF EXISTS fk_tasks_status;"
    execute "ALTER TABLE projects DROP CONSTRAINT IF EXISTS fk_projects_status;"

    # Restaura os CHECKs de lista fixa originais.
    add_check_constraint :tasks,
                         "status IN ('pending','todo','in_progress','done','canceled')",
                         name: "tasks_status_check"
    add_check_constraint :projects,
                         "status IN ('planning','in_progress','completed','on_hold')",
                         name: "projects_status_check"

    remove_check_constraint :tasks,    name: "tasks_status_entity_check"
    remove_check_constraint :projects, name: "projects_status_entity_check"
    remove_column :tasks,    :status_entity
    remove_column :projects, :status_entity

    drop_table :configurable_statuses
  end

  private

  # Monta uma tupla VALUES sem hardcode de UUID (gen_random_uuid no banco).
  def seed_row(entity, key, name, color, position, active, final, now)
    ts = quote(now)
    "(gen_random_uuid(), #{quote(entity)}, #{quote(key)}, #{quote(name)}, " \
      "#{quote(color)}, #{position}, #{active}, #{final}, #{ts}, #{ts})"
  end
end
