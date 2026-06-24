# PB-019a — CRUD da Empresa Prestadora, no padrão de cadastro do Omni
# (lista + páginas Nova/Editar com _form em card), dentro do espaço de Configurações.
# Sem `show` (a edição é a tela de detalhe). Sem vínculos nesta fatia (Contratos =
# PB-019b); o `rescue InvalidForeignKey` protege vínculos futuros.
class ProviderCompaniesController < ApplicationController
  before_action :set_provider_company, only: %i[edit update destroy]

  def index
    @provider_companies = policy_scope(ProviderCompany).ordered
  end

  def new
    @provider_company = ProviderCompany.new
    authorize @provider_company
    @return_to = return_to_param # PB-013b
  end

  def create
    @provider_company = ProviderCompany.new(provider_company_params)
    authorize @provider_company
    if @provider_company.save
      redirect_to provider_companies_path, notice: "Empresa prestadora criada."
    else
      @return_to = return_to_param
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @return_to = return_to_param
  end

  def update
    if @provider_company.update(provider_company_params)
      redirect_to safe_return_to(fallback: provider_companies_path), notice: "Empresa prestadora atualizada."
    else
      @return_to = return_to_param
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @provider_company.destroy!
    redirect_to safe_return_to(fallback: provider_companies_path), notice: "Empresa prestadora removida."
  rescue ActiveRecord::InvalidForeignKey
    # Rede de proteção para vínculos futuros (ex.: contratos — PB-019b).
    redirect_to provider_companies_path,
                alert: "A empresa prestadora possui vínculos e não pode ser excluída."
  end

  private

  def set_provider_company
    @provider_company = ProviderCompany.find(params[:id])
    authorize @provider_company
  end

  def provider_company_params
    params.require(:provider_company)
          .permit(:name, :trade_name, :cnpj, :email, :phone, :address, :active)
  end
end
