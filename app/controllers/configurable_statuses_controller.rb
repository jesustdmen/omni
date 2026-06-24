# PB-018 — CRUD dos status configuráveis (Tarefas/Projetos), administrados na
# página de Configurações. Apenas as entidades 'task' e 'project' são gerenciadas
# aqui; Demanda permanece com status fixo (não passa por este controller).
#
# Regras de integridade (contrato PB-018):
#   - chave única por entidade, snake_case ASCII (validação no model);
#   - nome presente; cor por allowlist de formato (hex);
#   - status EM USO não pode ser excluído (bloqueio amigável + FK ON DELETE RESTRICT
#     como rede de proteção final no banco);
#   - inativar é permitido (deixa de aparecer para NOVOS registros, mas continua
#     válido nos antigos).
class ConfigurableStatusesController < ApplicationController
  before_action :set_status, only: %i[update destroy]

  def create
    @status = ConfigurableStatus.new(create_params)
    authorize @status
    if @status.save
      redirect_to settings_path(anchor: "status-#{@status.entity_type}"),
                  notice: "Status “#{@status.name}” criado."
    else
      redirect_to settings_path(anchor: "status-#{@status.entity_type}"),
                  alert: "Não foi possível criar o status: #{error_text(@status)}"
    end
  end

  def update
    authorize @status
    if @status.update(update_params)
      redirect_to settings_path(anchor: "status-#{@status.entity_type}"),
                  notice: "Status “#{@status.name}” atualizado."
    else
      redirect_to settings_path(anchor: "status-#{@status.entity_type}"),
                  alert: "Não foi possível atualizar o status: #{error_text(@status)}"
    end
  end

  def destroy
    authorize @status
    if @status.in_use?
      redirect_to settings_path(anchor: "status-#{@status.entity_type}"),
                  alert: "O status “#{@status.name}” está em uso e não pode ser excluído. " \
                         "Mova os registros para outro status antes de excluir."
      return
    end

    begin
      @status.destroy!
      redirect_to settings_path(anchor: "status-#{@status.entity_type}"),
                  notice: "Status “#{@status.name}” excluído."
    rescue ActiveRecord::InvalidForeignKey
      # Rede de proteção: corrida entre a checagem e o delete (FK RESTRICT no banco).
      redirect_to settings_path(anchor: "status-#{@status.entity_type}"),
                  alert: "O status “#{@status.name}” está em uso e não pode ser excluído."
    end
  end

  private

  def set_status
    @status = ConfigurableStatus.find(params[:id])
  end

  # `entity_type` só é definido na CRIAÇÃO (e via allowlist); nunca pode mudar depois
  # (a FK e o discriminador dependem dele).
  def create_params
    p = params.require(:configurable_status).permit(:entity_type, :key, :name, :color, :position, :active, :final)
    p[:entity_type] = nil unless ConfigurableStatus::ENTITY_TYPES.include?(p[:entity_type])
    p
  end

  def update_params
    # entity_type e key não são editáveis (key é referenciada pela FK; trocar quebraria
    # registros). Edita-se nome/cor/posição/ativo/finalizador.
    params.require(:configurable_status).permit(:name, :color, :position, :active, :final)
  end

  def error_text(record)
    record.errors.full_messages.to_sentence
  end
end
