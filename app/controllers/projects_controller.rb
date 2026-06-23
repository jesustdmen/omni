class ProjectsController < ApplicationController
  include Paginated # paginação (allowlist + "Mostrar tudo")
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
    @statuses = Project::STATUSES
    @filters_active = project_filters_active?
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

  def filtered_projects(scope)
    scope = apply_project_search(scope)
    scope = scope.where(client_id: params[:client_id]) if valid_client?(params[:client_id])
    scope = scope.where(status: params[:status]) if Project::STATUSES.include?(params[:status])
    scope
  end

  def apply_project_search(scope)
    term = params[:q].to_s.strip
    return scope if term.blank?

    # Escapa curingas do LIKE (% e _) e o escape (\) → tratados como texto.
    pattern = "%#{term.gsub('\\', '\\\\\\\\').gsub('%', '\\%').gsub('_', '\\_')}%"
    scope.where("name ILIKE :p OR description ILIKE :p", p: pattern)
  end

  def valid_client?(client_id)
    client_id.present? && Client.exists?(id: client_id)
  end

  def project_filters_active?
    params[:q].present? || valid_client?(params[:client_id]) || Project::STATUSES.include?(params[:status])
  end

  # sanitized_per_page / show_all_per_page? vêm de Paginated.

  def sanitized_page(total_pages)
    page = params[:page].to_i
    return 1 if page < 1 || page > total_pages

    page
  end
end
