class DemandsController < ApplicationController
  before_action :set_demand, only: %i[show edit update destroy convert]

  def index
    @demands = policy_scope(Demand).includes(:client).order(created_at: :desc)
  end

  def show
    # PB-004c — tarefa criada a partir desta demanda (0 ou 1), para link/estado.
    @converted_task = @demand.converted_task
  end

  def new
    @demand = Demand.new
    authorize @demand
  end

  def create
    @demand = Demand.new(demand_params)
    authorize @demand
    if @demand.save
      redirect_to @demand, notice: "Demanda criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @demand.update(demand_params)
      redirect_to @demand, notice: "Demanda atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # PB-004c — bloqueio amigável: demanda com tarefa de origem não é excluível
    # (a FK RESTRICT é a proteção final; aqui damos a mensagem clara).
    if @demand.converted_task.present?
      redirect_to @demand, alert: "Esta demanda gerou uma tarefa e não pode ser excluída. Exclua a tarefa primeiro (a demanda voltará a pendente)."
    elsif @demand.destroy
      redirect_to demands_path, notice: "Demanda removida."
    else
      redirect_to @demand, alert: "Não foi possível remover a demanda."
    end
  end

  def convert
    result = ConvertDemand.call(@demand)
    if result.success?
      redirect_to result.task, notice: "Demanda convertida em tarefa."
    else
      redirect_to @demand, alert: result.error
    end
  end

  private

  def set_demand
    @demand = Demand.find(params[:id])
    authorize @demand
  end

  def demand_params
    params.require(:demand).permit(:title, :description, :origin, :priority, :client_id, :observations)
  end
end
