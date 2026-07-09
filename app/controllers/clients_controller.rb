class ClientsController < ApplicationController
  include Paginated # paginação (allowlist + "Mostrar tudo")
  include MultiFilter # PB-023e — filtros multi-valor (array-safe + allowlist)
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

  # PB-023e — seleções sanitizadas (multi-valor) para a barra de filtros.
  # `status` é freeform (valores distintos do banco); `primary` é yes/no.
  helper_method :selected_client_filters
  def selected_client_filters
    statuses = Client.distinct.pluck(:status).compact.map(&:to_s)
    @selected_client_filters ||= {
      status: filter_list(:status, allowlist: statuses),
      client_id: filter_ids(:client_id, Client),
      primary: filter_list(:primary, allowlist: %w[yes no])
    }
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
    statuses = selected_client_filters[:status]
    scope = scope.where(status: statuses) if statuses.any?
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
    params[:q].present? || selected_client_filters[:status].any?
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
    sel = selected_client_filters
    term = params[:q].to_s.strip
    if term.present?
      p = "%#{escape_like(term)}%"
      scope = scope.where("contacts.name ILIKE :p OR contacts.email ILIKE :p OR contacts.phone ILIKE :p OR contacts.position ILIKE :p", p: p)
    end
    scope = scope.where(client_id: sel[:client_id]) if sel[:client_id].any?
    scope = scope.joins(:client).where(clients: { status: sel[:status] }) if sel[:status].any?
    # `primary` yes/no → booleano. Marcar ambos (ou nenhum) = sem filtro.
    scope = apply_primary_filter(scope, sel[:primary])
    scope
  end

  # yes → is_primary true; no → false; ambos/vazio → não filtra.
  def apply_primary_filter(scope, primary)
    return scope unless primary.size == 1

    scope.where(is_primary: primary.first == "yes")
  end

  def contact_filters_active?
    sel = selected_client_filters
    params[:q].present? || sel[:client_id].any? || sel[:status].any? || sel[:primary].any?
  end

  # --- helpers comuns ------------------------------------------------------

  # Escapa curingas do LIKE (% e _) e o escape (\) → tratados como texto.
  def escape_like(term)
    term.gsub("\\", "\\\\\\\\").gsub("%", "\\%").gsub("_", "\\_")
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
