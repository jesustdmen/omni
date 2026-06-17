class TimeEntriesController < ApplicationController
  before_action :set_time_entry, only: %i[show edit update destroy]

  def index
    @time_entries = policy_scope(TimeEntry).includes(task: :client).order(start_time: :desc)
  end

  def show; end

  def new
    # task_id pode vir pré-selecionado quando criado a partir de /tasks/:id.
    @time_entry = TimeEntry.new(task_id: params[:task_id])
    authorize @time_entry
  end

  def create
    @time_entry = TimeEntry.new(time_entry_params)
    authorize @time_entry
    if @time_entry.save
      redirect_to @time_entry, notice: "Apontamento criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @time_entry.update(time_entry_params)
      redirect_to @time_entry, notice: "Apontamento atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @time_entry.destroy
    redirect_to time_entries_path, notice: "Apontamento removido."
  end

  private

  def set_time_entry
    @time_entry = TimeEntry.find(params[:id])
    authorize @time_entry
  end

  # conversation_id é deliberadamente OMITIDO: é coluna de preparação para fase
  # futura (F3/F4), sem FK/lógica/formulário — não atribuível via params.
  def time_entry_params
    params.require(:time_entry).permit(:task_id, :description, :start_time, :end_time, :duration, :date, :is_running)
  end
end
