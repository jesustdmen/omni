# PB-020a — Apuração de horas trabalhadas (read-only). Controller fino: parseia
# filtros e delega a regra ao service `WorkTimeReport`. NÃO aplica contrato, NÃO
# calcula valor, NÃO grava nada. Período padrão = mês atual no timezone operacional
# (Brasília — ADR-023). Autenticação via Devise; sem Pundit (não-resourceful, leitura).
class WorkTimeReportsController < ApplicationController
  def index
    @start_date, @end_date = parse_period
    @client_id = valid_id?(Client, params[:client_id]) ? params[:client_id] : nil
    @project_id = valid_id?(Project, params[:project_id]) ? params[:project_id] : nil
    @task_id = valid_id?(Task, params[:task_id]) ? params[:task_id] : nil
    @include_without_hours = ActiveModel::Type::Boolean.new.cast(params[:include_without_hours])

    @report = WorkTimeReport.call(
      start_date: @start_date, end_date: @end_date,
      client_id: @client_id, project_id: @project_id, task_id: @task_id,
      include_without_hours: @include_without_hours
    )

    # Opções de filtro (conjuntos pequenos; nomes para os blocos de totais).
    @clients = Client.ordered.pluck(:name, :id)
    @projects = Project.includes(:client).order(:name).map { |p| [ "#{p.name} — #{p.client.name}", p.id ] }
    @client_names = Client.where(id: @report.seconds_by_client.keys).pluck(:id, :name).to_h
    @project_names = Project.where(id: @report.seconds_by_project.keys.compact).pluck(:id, :name).to_h
  end

  private

  # Período por TimeEntry.date. Default: mês atual no Time.zone (Brasília).
  def parse_period
    today = Time.zone.today
    start_default = today.beginning_of_month
    end_default = today.end_of_month
    s = parse_date(params[:start_date]) || start_default
    e = parse_date(params[:end_date]) || end_default
    e < s ? [ s, s ] : [ s, e ] # fim antes do início → degrada para 1 dia (sem erro)
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def valid_id?(model, id)
    id.present? && model.exists?(id: id)
  end
end
