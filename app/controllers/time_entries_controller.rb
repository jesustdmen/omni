class TimeEntriesController < ApplicationController
  before_action :set_time_entry, only: %i[show edit update destroy]

  def index
    @time_entries = policy_scope(TimeEntry).includes(task: :client).order(start_time: :desc)
  end

  # PB-003c — lista global de timers em andamento (sem dashboard/tick ao vivo).
  def running
    authorize TimeEntry, :index?
    @time_entries = policy_scope(TimeEntry).running.includes(task: :client).order(start_time: :desc)
  end

  def show
    @return_to = return_to_param # PB-013b
  end

  def new
    # PB-003c — apontamento retroativo assistido: defaults (tarefa pré-selecionada
    # quando vier de /tasks/:id; início = agora sem segundos; término em branco).
    @time_entry = TimeEntry.new(task_id: params[:task_id], start_time: Time.current.change(sec: 0))
    authorize @time_entry
    @return_to = return_to_param
  end

  def create
    @time_entry = TimeEntry.new(time_entry_params)
    authorize @time_entry
    if @time_entry.save
      # PB-013b — volta à origem (tarefa#tab-time ou lista global), senão ao detalhe.
      redirect_to safe_return_to(fallback: @time_entry), notice: "Apontamento criado."
    else
      @return_to = return_to_param
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @return_to = return_to_param
  end

  def update
    # PB-003c — em timer running, CRUD genérico só altera descrição (campos
    # temporais/tarefa são geridos por start_for/stop!).
    attrs = @time_entry.is_running ? time_entry_params.slice(:description) : time_entry_params
    if @time_entry.update(attrs)
      redirect_to safe_return_to(fallback: @time_entry), notice: "Apontamento atualizado." # PB-013b
    else
      @return_to = return_to_param
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @time_entry.destroy
    # PB-013b — volta à origem (tarefa#tab-time ou lista global), senão à lista.
    redirect_to safe_return_to(fallback: time_entries_path), notice: "Apontamento removido."
  end

  # PB-003a — para um timer em andamento (calcula duração em segundos).
  # Carrega/autoriza aqui (não via set_time_entry) usando `:update?` — sem
  # introduzir `stop?` na policy.
  def stop
    @time_entry = TimeEntry.find(params[:id])
    authorize @time_entry, :update?
    @time_entry.stop!
    # PB-013b — return_to seguro tem prioridade; mantém o referer seguro como fallback.
    redirect_to safe_return_to(fallback: @time_entry.task), notice: "Timer parado."
  end

  private

  def set_time_entry
    @time_entry = TimeEntry.find(params[:id])
    authorize @time_entry
  end

  # PB-003c — apenas campos editáveis pelo usuário no apontamento retroativo.
  # OMITIDOS de propósito: `date` e `duration` (derivados no model), `is_running`
  # (controlado só por start_for/stop!) e `conversation_id` (preparação futura).
  def time_entry_params
    params.require(:time_entry).permit(:task_id, :description, :start_time, :end_time)
  end
end
