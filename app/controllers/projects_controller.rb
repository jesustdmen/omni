class ProjectsController < ApplicationController
  include Paginated # paginação (allowlist + "Mostrar tudo")
  include MultiFilter # PB-023e — filtros multi-valor (array-safe + allowlist)
  before_action :set_project, only: %i[show edit update destroy duplicate]

  PER_PAGE_OPTIONS = Paginated::PER_PAGE_OPTIONS
  DEFAULT_PER_PAGE = Paginated::DEFAULT_PER_PAGE

  def index
    scope = filtered_projects(policy_scope(Project))
    @total_count = scope.count
    @per_page = sanitized_per_page
    @show_all = show_all_per_page?
    @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
    @page = sanitized_page(@total_pages)
    @projects = scope
      .includes(:client)
      .order(:name, :id)
      .limit(@per_page)
      .offset((@page - 1) * @per_page)
    @clients = Client.ordered.pluck(:name, :id)
    # PB-018 — opções de filtro da tabela de status configuráveis (entity 'project').
    # Inclui inativos (filtrar registros antigos). Pares [label, key].
    @status_options = ConfigurableStatus.for_entity(Project::STATUS_ENTITY).ordered.pluck(:name, :key)
    @filters_active = project_filters_active?
  end

  # PB-023e — seleções sanitizadas (multi-valor) para a barra de filtros.
  helper_method :selected_project_filters
  def selected_project_filters
    @selected_project_filters ||= {
      status: filter_list(:status, allowlist: ConfigurableStatus.for_entity(Project::STATUS_ENTITY).pluck(:key)),
      client_id: filter_ids(:client_id, Client)
    }
  end

  def show
    @return_to = return_to_param # PB-013b
  end

  def new
    @project = Project.new
    authorize @project
    @return_to = return_to_param
  end

  def create
    @project = Project.new(project_params)
    authorize @project
    if @project.save
      redirect_to @project, notice: "Projeto criado."
    else
      @return_to = return_to_param
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @return_to = return_to_param
  end

  def update
    if @project.update(project_params)
      redirect_to safe_return_to(fallback: @project), notice: "Projeto atualizado." # PB-013b
    else
      @return_to = return_to_param
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to safe_return_to(fallback: projects_path), notice: "Projeto removido." # PB-013b
  end

  # PB-007 — duplica o projeto (transacional; só campos autorizados) e leva à edição.
  def duplicate
    authorize @project, :create?
    result = DuplicateProject.call(@project)
    if result.success?
      redirect_to edit_project_path(result.project), notice: "Projeto duplicado. Ajuste os dados da cópia."
    else
      redirect_to projects_path, alert: "Não foi possível duplicar o projeto."
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
    authorize @project
  end

  def project_params
    params.require(:project).permit(:client_id, :name, :description, :start_date, :end_date, :status, :budget)
  end

  # --- PB-007 — busca, filtros e paginação ---------------------------------

  # PB-023e — filtros multi-valor (cliente/status aceitam 1..N valores).
  def filtered_projects(scope)
    sel = selected_project_filters
    scope = apply_project_search(scope)
    scope = scope.where(client_id: sel[:client_id]) if sel[:client_id].any?
    scope = scope.where(status: sel[:status]) if sel[:status].any?
    scope
  end

  def apply_project_search(scope)
    term = params[:q].to_s.strip
    return scope if term.blank?

    # Escapa curingas do LIKE (% e _) e o escape (\) → tratados como texto.
    pattern = "%#{term.gsub('\\', '\\\\\\\\').gsub('%', '\\%').gsub('_', '\\_')}%"
    scope.where("name ILIKE :p OR description ILIKE :p", p: pattern)
  end

  def project_filters_active?
    params[:q].present? || selected_project_filters.values.any?(&:any?)
  end

  # sanitized_per_page / show_all_per_page? vêm de Paginated.

  def sanitized_page(total_pages)
    page = params[:page].to_i
    return 1 if page < 1 || page > total_pages

    page
  end
end
