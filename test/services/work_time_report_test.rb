require "test_helper"

# PB-020a — Apuração de horas trabalhadas (service). Read-only; sem contrato/valor.
class WorkTimeReportTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
    @other_client = Client.create!(name: "Globex")
    @project = @client.projects.create!(name: "Proj A", status: "planning")
    @task = @client.tasks.create!(title: "Tarefa A", type: "support", project: @project)
    @task_b = @other_client.tasks.create!(title: "Tarefa B", type: "support")
  end

  # Cria apontamento concluído (retroativo) num dia, com `secs` segundos.
  def entry(task, date, secs)
    start_t = Time.zone.local(date.year, date.month, date.day, 9, 0, 0)
    TimeEntry.create!(task: task, start_time: start_t, end_time: start_t + secs, is_running: false)
  end

  test "apura horas por tarefa somando duration em segundos" do
    entry(@task, Date.new(2026, 6, 10), 3600)
    entry(@task, Date.new(2026, 6, 11), 1800)
    r = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30))
    row = r.rows.find { |x| x.task.id == @task.id }
    assert_equal 5400, row.seconds
    assert_equal 2, row.entries_count
    assert_kind_of Integer, row.seconds # sem float
  end

  test "filtra pelo período usando TimeEntry.date (fora do período não entra)" do
    entry(@task, Date.new(2026, 6, 15), 3600) # dentro
    entry(@task, Date.new(2026, 7, 1), 9999)  # fora
    r = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30))
    assert_equal 3600, r.totals.seconds
    assert_equal 1, r.totals.entries_count
  end

  test "fronteiras de data são inclusivas (start_date e end_date)" do
    entry(@task, Date.new(2026, 6, 1), 100)
    entry(@task, Date.new(2026, 6, 30), 200)
    r = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30))
    assert_equal 300, r.totals.seconds
  end

  test "agrupa totais por cliente e por projeto" do
    entry(@task, Date.new(2026, 6, 5), 3600)       # client ACME / Proj A
    entry(@task_b, Date.new(2026, 6, 5), 1800)     # other client / sem projeto
    r = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30))
    assert_equal 3600, r.seconds_by_client[@client.id]
    assert_equal 1800, r.seconds_by_client[@other_client.id]
    assert_equal 3600, r.seconds_by_project[@project.id]
    assert_equal 1800, r.seconds_by_project[nil] # "Sem projeto"
  end

  test "filtro por cliente restringe o resultado" do
    entry(@task, Date.new(2026, 6, 5), 3600)
    entry(@task_b, Date.new(2026, 6, 5), 1800)
    r = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30), client_id: @client.id)
    assert_equal 3600, r.totals.seconds
    assert_equal [ @task.id ], r.rows.map { |x| x.task.id }
  end

  test "filtro por projeto restringe o resultado" do
    entry(@task, Date.new(2026, 6, 5), 3600)
    entry(@task_b, Date.new(2026, 6, 5), 1800)
    r = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30), project_id: @project.id)
    assert_equal 3600, r.totals.seconds
  end

  test "timer em andamento (running) não distorce o total" do
    entry(@task, Date.new(2026, 6, 10), 3600)
    TimeEntry.start_for(@task, at: Time.zone.local(2026, 6, 12, 9, 0, 0)) # running, duration 0
    r = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30))
    assert_equal 3600, r.totals.seconds, "running não soma"
    assert_equal 1, r.totals.entries_count, "running não conta como apontamento concluído"
  end

  test "tarefa com conversa vinculada e sem horas aparece só quando incluir-sem-horas" do
    @task.update_columns(conversation_count: 2) # evidência sem apontamento no período
    sem = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30))
    assert_empty sem.rows, "sem a opção, tarefa sem horas não aparece"

    com = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30), include_without_hours: true)
    row = com.rows.find { |x| x.task.id == @task.id }
    assert_not_nil row
    assert_equal 0, row.seconds
    assert_not row.with_hours?
    assert_equal 2, row.conversations_count
    assert_equal 1, com.totals.tasks_without_hours
  end

  test "incluir-sem-horas NÃO duplica tarefa que já tem horas no período" do
    @task.update_columns(conversation_count: 3)
    entry(@task, Date.new(2026, 6, 7), 600)
    r = WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30), include_without_hours: true)
    assert_equal 1, r.rows.count { |x| x.task.id == @task.id }
    assert_equal 600, r.rows.find { |x| x.task.id == @task.id }.seconds
  end

  test "não grava nada (read-only)" do
    entry(@task, Date.new(2026, 6, 9), 1200)
    assert_no_difference([ "TimeEntry.count", "Task.count", "Contract.count" ]) do
      WorkTimeReport.call(start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 30), include_without_hours: true)
    end
  end
end
