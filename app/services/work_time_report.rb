# PB-020a — Apuração de horas trabalhadas (read-only).
#
# Consolida HORAS (não valor) por tarefa dentro de um período, com totais por
# cliente/projeto e geral. Fonte: TimeEntry (date = dia operacional em Brasília,
# ADR-023; duration em SEGUNDOS) + Task/Client/Project. Conversas vinculadas
# (`Task#conversation_count`) entram apenas como EVIDÊNCIA (contagem), nunca como
# tempo inferido. NÃO aplica contrato, NÃO calcula valor, NÃO grava nada.
#
# Opcional: incluir tarefas SEM apontamentos no período mas COM conversa vinculada
# (evidência de trabalho) — exibidas como "Sem horas lançadas".
#
# `duration` é sempre tratado em segundos (Integer); arredondamento é só visual na
# view (helper `duration_label`). Sem float em regra interna.
class WorkTimeReport
  # Uma linha da apuração (por tarefa).
  Row = Struct.new(:task, :seconds, :entries_count, :conversations_count, keyword_init: true) do
    def with_hours? = seconds.positive?
  end

  Totals = Struct.new(:seconds, :entries_count, :tasks_count, :conversations_count,
                      :tasks_without_hours, keyword_init: true)

  def self.call(**kwargs)
    new(**kwargs).tap(&:run)
  end

  attr_reader :rows, :totals, :start_date, :end_date

  # `scope` = TimeEntry base já com policy_scope aplicada (injetável p/ teste).
  def initialize(start_date:, end_date:, client_id: nil, project_id: nil, task_id: nil,
                 include_without_hours: false, entries_scope: TimeEntry.all, tasks_scope: Task.all)
    @start_date = start_date
    @end_date = end_date
    @client_id = client_id.presence
    @project_id = project_id.presence
    @task_id = task_id.presence
    @include_without_hours = include_without_hours
    @entries_scope = entries_scope
    @tasks_scope = tasks_scope
    @rows = []
    @totals = Totals.new(seconds: 0, entries_count: 0, tasks_count: 0,
                         conversations_count: 0, tasks_without_hours: 0)
  end

  def run
    by_task = aggregate_entries           # { task_id => [seconds, entries_count] }
    tasks = load_tasks(by_task.keys)      # tarefas com horas no período (com includes)

    @rows = tasks.map do |task|
      seconds, count = by_task[task.id]
      Row.new(task: task, seconds: seconds, entries_count: count,
              conversations_count: task.conversation_count)
    end

    add_tasks_without_hours!(by_task.keys) if @include_without_hours

    sort_rows!
    compute_totals!
    self
  end

  # Totais por chave (id => segundos) para os blocos "por cliente"/"por projeto".
  def seconds_by_client
    group_seconds { |row| row.task.client_id }
  end

  def seconds_by_project
    group_seconds { |row| row.task.project_id } # nil = "Sem projeto"
  end

  private

  # Soma segundos e conta apontamentos por tarefa, no período (TimeEntry.date) e
  # filtros. Exclui timers em andamento (duration=0 por regra, mas explícito evita
  # contá-los como "apontamento" concluído). 1 query agregada (sem N+1).
  def aggregate_entries
    scope = period_scope
    grouped_seconds = scope.group(:task_id).sum(:duration)
    grouped_counts  = scope.group(:task_id).count
    grouped_seconds.each_with_object({}) do |(task_id, secs), acc|
      acc[task_id] = [ secs.to_i, grouped_counts[task_id].to_i ]
    end
  end

  def period_scope
    scope = @entries_scope
            .where(is_running: false)
            .where(date: @start_date..@end_date)
    scope = scope.where(task_id: @task_id) if @task_id
    if @client_id || @project_id
      scope = scope.joins(:task)
      scope = scope.where(tasks: { client_id: @client_id }) if @client_id
      scope = scope.where(tasks: { project_id: @project_id }) if @project_id
    end
    scope
  end

  def load_tasks(task_ids)
    return [] if task_ids.empty?

    @tasks_scope.where(id: task_ids).includes(:client, :project).to_a
  end

  # Tarefas SEM apontamento no período, mas COM conversa vinculada (evidência),
  # respeitando os filtros de cliente/projeto/tarefa. Aparecem com seconds=0.
  def add_tasks_without_hours!(task_ids_with_hours)
    scope = @tasks_scope.where("conversation_count > 0").where.not(id: task_ids_with_hours)
    scope = scope.where(id: @task_id) if @task_id
    scope = scope.where(client_id: @client_id) if @client_id
    scope = scope.where(project_id: @project_id) if @project_id

    scope.includes(:client, :project).find_each do |task|
      @rows << Row.new(task: task, seconds: 0, entries_count: 0,
                       conversations_count: task.conversation_count)
    end
  end

  # Mais horas primeiro; depois título (estável). Linhas sem horas ao final.
  def sort_rows!
    @rows.sort_by! { |r| [ -r.seconds, r.task.title.to_s.downcase, r.task.id ] }
  end

  def compute_totals!
    @totals = Totals.new(
      seconds: @rows.sum(&:seconds),
      entries_count: @rows.sum(&:entries_count),
      tasks_count: @rows.size,
      conversations_count: @rows.sum(&:conversations_count),
      tasks_without_hours: @rows.count { |r| !r.with_hours? }
    )
  end

  def group_seconds
    @rows.each_with_object(Hash.new(0)) { |row, acc| acc[yield(row)] += row.seconds }
  end
end
