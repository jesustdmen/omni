class DemandsController < ApplicationController
  before_action :set_demand, only: %i[show edit update destroy convert]

  # PB-005 — paginação (allowlist) e default (mesmo padrão da PB-004a).
  PER_PAGE_OPTIONS = [ 10, 25, 50, 100 ].freeze
  DEFAULT_PER_PAGE = 50

  def index
    scope = filtered_demands(policy_scope(Demand))

    @total_count = scope.count # antes de limit/offset; sem includes
    @per_page = sanitized_per_page
    @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
    @page = sanitized_page(@total_pages)

    @demands = scope
      .includes(:client, :converted_task)
      .order(created_at: :desc, id: :desc)
      .limit(@per_page)
      .offset((@page - 1) * @per_page)

    @clients = Client.order(:name).pluck(:name, :id)
    @statuses = Demand.statuses.keys
    @priorities = Demand::PRIORITIES
    @origins = Demand::ORIGINS
    @filters_active = demand_filters_active?
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

  # --- PB-005 — busca, filtros e paginação (padrão PB-004a) -----------------

  def filtered_demands(scope)
    scope = apply_demand_search(scope)
    scope = scope.where(priority: params[:priority]) if Demand::PRIORITIES.include?(params[:priority])
    scope = scope.where(origin: params[:origin]) if Demand::ORIGINS.include?(params[:origin])
    scope = scope.where(status: params[:status]) if Demand.statuses.key?(params[:status])
    scope = scope.where(client_id: params[:client_id]) if valid_client?(params[:client_id])
    scope
  end

  def apply_demand_search(scope)
    term = params[:q].to_s.strip
    return scope if term.blank?

    # Escapa curingas do LIKE (% e _) e o escape (\) → tratados como texto.
    pattern = "%#{term.gsub('\\', '\\\\\\\\').gsub('%', '\\%').gsub('_', '\\_')}%"
    scope.where("title ILIKE :p OR description ILIKE :p OR observations ILIKE :p", p: pattern)
  end

  def valid_client?(client_id)
    client_id.present? && Client.exists?(id: client_id)
  end

  def demand_filters_active?
    params[:q].present? || Demand::PRIORITIES.include?(params[:priority]) ||
      Demand::ORIGINS.include?(params[:origin]) || Demand.statuses.key?(params[:status]) ||
      valid_client?(params[:client_id])
  end

  def sanitized_per_page
    pp = params[:per_page].to_i
    PER_PAGE_OPTIONS.include?(pp) ? pp : DEFAULT_PER_PAGE
  end

  def sanitized_page(total_pages)
    page = params[:page].to_i
    return 1 if page < 1 || page > total_pages

    page
  end
end
