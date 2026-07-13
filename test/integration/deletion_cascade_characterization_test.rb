require "test_helper"

# ⚠️ CARACTERIZAÇÃO DE COMPORTAMENTO PERIGOSO EXISTENTE — NÃO É REGRA DESEJADA.
#
# Onda 0 (escopo C — integridade de exclusões). Este teste **documenta** o
# comportamento ATUAL de cascade ao excluir um Client, que é considerado
# **arriscado** e contradiz `docs/DATABASE_DOMAINS.md` (§3/§4): tarefas,
# apontamentos e projetos são registros humanos reais e NÃO deveriam sumir
# junto com o cliente.
#
# Situação atual (FK no banco + `dependent:` no model Client):
#   - projects → clients : on_delete cascade  (Client has_many :projects, dependent: :destroy)
#   - tasks    → clients : on_delete cascade  (Client has_many :tasks,    dependent: :destroy)
#   - checklist_items → tasks : cascade ; time_entries → tasks : cascade ;
#     conversation_links → tasks : cascade
#   Logo: destruir um Client APAGA em cascata projetos, tarefas, checklists,
#   apontamentos e vínculos de conversa daquele cliente.
#
# NENHUMA migration/alteração de comportamento é aplicada nesta onda. A política
# proposta (restrict + arquivamento) fica registrada como **decisão pendente do
# PO** no DELIVERY_LOG. Se/quando a exclusão passar a ser protegida, este teste
# deve ser REESCRITO para refletir a nova regra (a falha aqui será o sinal).
class DeletionCascadeCharacterizationTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME (caracterização)")
    @project = @client.projects.create!(name: "Projeto X", status: "planning")
    @task = @client.tasks.create!(title: "Tarefa Y", type: "support", project: @project)
    @task.checklist_items.create!(content: "item")
    @task.time_entries.create!(start_time: Time.current, end_time: Time.current + 1.hour)
  end

  test "PERIGOSO/ATUAL: excluir Client apaga em cascata projetos, tarefas, checklist e apontamentos" do
    task_id = @task.id
    project_id = @project.id

    assert_difference -> { Client.count } => -1,
                      -> { Project.count } => -1,
                      -> { Task.count } => -1,
                      -> { ChecklistItem.count } => -1,
                      -> { TimeEntry.count } => -1 do
      @client.destroy
    end

    assert_nil Task.find_by(id: task_id), "comportamento atual: a tarefa some com o cliente (arriscado)"
    assert_nil Project.find_by(id: project_id), "comportamento atual: o projeto some com o cliente (arriscado)"
  end

  test "ATUAL: contrato (restrict_with_error) já bloqueia a exclusão do Client" do
    provider = ProviderCompany.create!(name: "Prestadora")
    Contract.create!(provider_company: provider, client: @client, hourly_rate: 100,
                     status: "active", start_date: Date.current)

    assert_no_difference -> { Client.count } do
      assert_not @client.destroy, "cliente com contrato não deve ser excluível (restrict_with_error)"
    end
  end
end
