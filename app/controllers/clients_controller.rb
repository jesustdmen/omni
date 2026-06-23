class ClientsController < ApplicationController
  include Paginated # paginação (allowlist + "Mostrar tudo")
  before_action :set_client, only: %i[show edit update destroy]

  # PB-006 — listagem operacional com abas Empresas/Contatos.
  PER_PAGE_OPTIONS = Paginated::PER_PAGE_OPTIONS
  DEFAULT_PER_PAGE = Paginated::DEFAULT_PER_PAGE
  TABS = %w[companies contacts].freeze

  def index
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "companies"
    @per_page = sanitized_per_page
    @show_all = show_all_per_page?
    @clients_for_filter = Client.ordered.pluck(:name, :id)
    @statuses = Client.distinct.pluck(:status).compact.sort

    @tab == "contacts" ? load_contacts : load_companies
  end

  def show
    @return_to = return_to_param # PB-013b
  end

  def new
    @client = Client.new
    authorize @client
    @return_to = return_to_param
  end

  def create
    @client = Client.new(client_params)
    authorize @client
    if @client.save
      redirect_to @client, notice: "Cliente criado."
    else
      @return_to = return_to_param
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @return_to = return_to_param
  end

  def update
    if @client.update(client_params)
      redirect_to safe_return_to(fallback: @client), notice: "Cliente atualizado." # PB-013b
    else
      @return_to = return_to_param
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy
    redirect_to safe_return_to(fallback: clients_path), notice: "Cliente removido." # PB-013b
  end

  private

  def set_client
    @client = Client.find(params[:id])
    authorize @client
  end

  def client_params
    params.require(:client).permit(
      :name, :trade_name, :cnpj, :phone, :address, :status, :workspace_paths_text,
      workspace_paths: []
    )
  end

  # --- Empresas ------------------------------------------------------------

  def load_companies
    scope = filtered_companies(policy_scope(Client))
    @total_count = scope.count
    @total_pages = total_pages(@total_count)
    @page = sanitized_page(@total_pages)
    @companies = scope
      .includes(:contacts)
      .order(:name, :id)
      .limit(@per_page)
      .offset((@page - 1) * @per_page)
    @companies_filters_active = company_filters_active?
  end

  def filtered_companies(scope)
    scope = apply_company_search(scope)
    scope = scope.where(status: params[:status]) if valid_status?(params[:status])
    scope
  end

  def apply_company_search(scope)
    term = params[:q].to_s.strip
    return scope if term.blank?

    digits = Client.normalize_cnpj_digits(term)
    pattern = "%#{escape_like(term)}%"
    if digits.present?
      cnpj_pattern = "%#{escape_like(digits)}%"
      scope.where("name ILIKE :p OR trade_name ILIKE :p OR cnpj LIKE :c", p: pattern, c: cnpj_pattern)
    else
      scope.where("name ILIKE :p OR trade_name ILIKE :p", p: pattern)
    end
  end

  def company_filters_active?
    params[:q].present? || valid_status?(params[:status])
  end

  # --- Contatos ------------------------------------------------------------

  def load_contacts
    scope = filtered_contacts(policy_scope(Contact))
    @total_count = scope.count
    @total_pages = total_pages(@total_count)
    @page = sanitized_page(@total_pages)
    @contacts = scope
      .includes(:client)
      .order(:name, :id)
      .limit(@per_page)
      .offset((@page - 1) * @per_page)
    @contacts_filters_active = contact_filters_active?
  end

  def filtered_contacts(scope)
    term = params[:q].to_s.strip
    if term.present?
      p = "%#{escape_like(term)}%"
      scope = scope.where("contacts.name ILIKE :p OR contacts.email ILIKE :p OR contacts.phone ILIKE :p OR contacts.position ILIKE :p", p: p)
    end
    scope = scope.where(client_id: params[:client_id]) if valid_client?(params[:client_id])
    scope = scope.joins(:client).where(clients: { status: params[:status] }) if valid_status?(params[:status])
    case params[:primary]
    when "yes" then scope = scope.where(is_primary: true)
    when "no" then scope = scope.where(is_primary: false)
    end
    scope
  end

  def contact_filters_active?
    params[:q].present? || valid_client?(params[:client_id]) ||
      valid_status?(params[:status]) || %w[yes no].include?(params[:primary])
  end

  # --- helpers comuns ------------------------------------------------------

  # Escapa curingas do LIKE (% e _) e o escape (\) → tratados como texto.
  def escape_like(term)
    term.gsub("\\", "\\\\\\\\").gsub("%", "\\%").gsub("_", "\\_")
  end

  def valid_status?(status)
    status.present? && Client.where(status: status).exists?
  end

  def valid_client?(client_id)
    client_id.present? && Client.exists?(id: client_id)
  end

  # sanitized_per_page / show_all_per_page? vêm de Paginated.

  def total_pages(count)
    [ (count.to_f / @per_page).ceil, 1 ].max
  end

  def sanitized_page(total_pages)
    page = params[:page].to_i
    return 1 if page < 1 || page > total_pages

    page
  end
end
