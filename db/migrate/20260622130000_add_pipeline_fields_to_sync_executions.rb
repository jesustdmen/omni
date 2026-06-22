# PB-016a — campos para a sincronização COMPLETA (pipeline + importação) orquestrada
# pelo Omni. Aditiva sobre `sync_executions` (não cria tabela nova; reutiliza a
# estrutura da PB-015):
#  - current_step        : etapa operacional corrente (UI de progresso por etapa);
#  - pipeline_exit_code  : exit code do runner do pipeline (nil quando não rodou);
#  - pipeline_summary    : resumo SEGURO do pipeline (sem paths/segredos/conteúdo).
class AddPipelineFieldsToSyncExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :sync_executions, :current_step, :string
    add_column :sync_executions, :pipeline_exit_code, :integer
    add_column :sync_executions, :pipeline_summary, :text
  end
end
