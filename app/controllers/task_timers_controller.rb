class TaskTimersController < ApplicationController
  # PB-003a — inicia um timer (TimeEntry running) para a tarefa.
  # Regras de unicidade/paralelismo ficam no model; o índice parcial é o backstop
  # de corrida. Redirect HTML (Turbo aceita o redirect; sem stream dedicado nesta fatia).
  def create
    @task = Task.find(params[:task_id])
    @time_entry = TimeEntry.new(task: @task)
    authorize @time_entry, :create?

    @time_entry = TimeEntry.start_for(@task)

    if @time_entry.persisted?
      redirect_to @task, notice: "Timer iniciado."
    else
      redirect_to @task, alert: @time_entry.errors.full_messages.to_sentence.presence || "Não foi possível iniciar o timer."
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to @task, alert: "Já existe um timer em andamento nesta tarefa."
  end
end
