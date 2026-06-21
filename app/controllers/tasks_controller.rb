class TasksController < ApplicationController
  before_action :set_task, only: %i[show edit update destroy]

  # PB-004a — opções de paginação (allowlist) e default.
  PER_PAGE_OPTIONS = [ 10, 25, 50, 100 ].freeze
  DEFAULT_PER_PAGE = 50

  def index
    scope = filtered_tasks(policy_scope(Task))

    # Total calculado ANTES de limit/offset (sem includes; não carrega tudo em memória).
    @total_count = scope.count
    @per_page = sanitized_per_page
    @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
    @page = sanitized_page(@total_pages)

    # Eager load de cliente/projeto só na página exibida (sem N+1). Ordenação estável.
    @tasks = scope
      .includes(:client, :project)
      .order(created_at: :desc, id: :desc)
      .limit(@per_page)
      .offset((@page - 1) * @per_page)

    # Opções de filtro (conjuntos pequenos).
    @clients = Client.order(:name).pluck(:name, :id)
    @statuses = Task.statuses.keys
    @types = Task::TYPES
    @filters_active = filters_active?
  end

  def show
    # F4 — conversas vinculadas (read-only) para a aba "Conversas".
    @linked_conversations = @task.conversation_links.includes(:conversation).order(:created_at)
  end

  def new
    @task = Task.new
    authorize @task
  end

  def create
    @task = Task.new(task_params)
    authorize @task
    if @task.save
      redirect_to @task, notice: "Tarefa criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @task.update(task_params)
      redirect_to @task, notice: "Tarefa atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    redirect_to tasks_path, notice: "Tarefa removida."
  end

  private

  def set_task
    @task = Task.find(params[:id])
    authorize @task
  end

  def task_params
    params.require(:task).permit(:client_id, :project_id, :title, :description, :type, :status)
  end

  # --- PB-004a — busca, filtros e paginação --------------------------------

  # Aplica busca (título/descrição) + filtros combináveis no BANCO. Valores
  # inválidos são ignorados com segurança (não filtram).
  def filtered_tasks(scope)
    scope = apply_search(scope)
    # Status/Tipo: só aplicam se forem valores conhecidos (allowlist).
    scope = scope.where(status: params[:status]) if Task.statuses.key?(params[:status])
    scope = scope.where(type: params[:type]) if Task::TYPES.include?(params[:type])
    # Cliente: aplica só se houver cliente com esse id (id inválido → ignora).
    scope = scope.where(client_id: params[:client_id]) if valid_client?(params[:client_id])
    scope
  end

  def apply_search(scope)
    term = params[:q].to_s.strip
    return scope if term.blank?

    # Escapa curingas do LIKE (% e _) e o próprio escape (\), tratando-os como texto.
    pattern = "%#{term.gsub('\\', '\\\\\\\\').gsub('%', '\\%').gsub('_', '\\_')}%"
    scope.where("title ILIKE :p OR description ILIKE :p", p: pattern)
  end

  def valid_client?(client_id)
    client_id.present? && Client.exists?(id: client_id)
  end

  def filters_active?
    params[:q].present? || Task.statuses.key?(params[:status]) ||
      Task::TYPES.include?(params[:type]) || valid_client?(params[:client_id])
  end

  def sanitized_per_page
    pp = params[:per_page].to_i
    PER_PAGE_OPTIONS.include?(pp) ? pp : DEFAULT_PER_PAGE
  end

  # Página inválida/negativa/acima do total → volta para a primeira.
  def sanitized_page(total_pages)
    page = params[:page].to_i
    return 1 if page < 1 || page > total_pages

    page
  end
end
