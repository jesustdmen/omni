# PB-019b — CRUD de Contratos (frente comercial; padrão de CRUD do Omni).
# Contrato = Empresa Prestadora + Cliente (+ Projeto opcional). Sobreposição é
# validada no model (Rails). NÃO toca TimeEntry; sem cálculo/fechamento/relatório.
class ContractsController < ApplicationController
  include Paginated
  include MultiFilter # PB-023e — filtros multi-valor (array-safe + allowlist)
  before_action :set_contract, only: %i[show edit update destroy]

  PER_PAGE_OPTIONS = Paginated::PER_PAGE_OPTIONS
  DEFAULT_PER_PAGE = Paginated::DEFAULT_PER_PAGE

  def index
    scope = filtered_contracts(policy_scope(Contract))
    @total_count = scope.count
    @per_page = sanitized_per_page
    @show_all = show_all_per_page?
    @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
    @page = sanitized_page(@total_pages)
    @contracts = scope
      .includes(:provider_company, :client, :project)
      .ordered
      .limit(@per_page)
      .offset((@page - 1) * @per_page)
    @provider_companies = ProviderCompany.ordered.pluck(:name, :id)
    @clients = Client.ordered.pluck(:name, :id)
    @filters_active = contract_filters_active?
  end

  # PB-023e — seleções sanitizadas (multi-valor) para a barra de filtros.
  helper_method :selected_contract_filters
  def selected_contract_filters
    @selected_contract_filters ||= {
      provider_company_id: filter_ids(:provider_company_id, ProviderCompany),
      client_id: filter_ids(:client_id, Client),
      status: filter_list(:status, allowlist: Contract::STATUSES)
    }
  end

  def show
    @return_to = return_to_param
  end

  def new
    @contract = Contract.new(start_date: Date.current)
    authorize @contract
    @return_to = return_to_param
  end

  def create
    @contract = Contract.new(contract_params)
    authorize @contract
    if @contract.save
      redirect_to @contract, notice: "Contrato criado."
    else
      @return_to = return_to_param
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @return_to = return_to_param
  end

  def update
    if @contract.update(contract_params)
      redirect_to safe_return_to(fallback: @contract), notice: "Contrato atualizado."
    else
      @return_to = return_to_param
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contract.destroy
    redirect_to safe_return_to(fallback: contracts_path), notice: "Contrato removido."
  end

  private

  def set_contract
    @contract = Contract.find(params[:id])
    authorize @contract
  end

  def contract_params
    params.require(:contract).permit(:provider_company_id, :client_id, :project_id,
                                     :start_date, :end_date, :status, :hourly_rate, :notes)
  end

  # Busca por observações + filtros combináveis (allowlist; inválidos ignorados).
  def filtered_contracts(scope)
    term = params[:q].to_s.strip
    if term.present?
      pattern = "%#{term.gsub('\\', '\\\\\\\\').gsub('%', '\\%').gsub('_', '\\_')}%"
      scope = scope.where("notes ILIKE :p", p: pattern)
    end
    sel = selected_contract_filters
    scope = scope.where(provider_company_id: sel[:provider_company_id]) if sel[:provider_company_id].any?
    scope = scope.where(client_id: sel[:client_id]) if sel[:client_id].any?
    scope = scope.where(status: sel[:status]) if sel[:status].any?
    scope
  end

  def contract_filters_active?
    params[:q].present? || selected_contract_filters.values.any?(&:any?)
  end

  # sanitized_per_page / show_all_per_page? vêm de Paginated.
  def sanitized_page(total_pages)
    page = params[:page].to_i
    return 1 if page < 1 || page > total_pages

    page
  end
end
