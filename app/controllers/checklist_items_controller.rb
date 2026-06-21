# PB-004b — checklist persistente da tarefa. Aninhado em /tasks/:task_id/checklist_items.
# Itens são SEMPRE buscados pelo escopo da tarefa da URL (impede manipular item de
# outra tarefa cruzando IDs). Volta sempre ao contexto da tarefa (#tab-detalhes).
class ChecklistItemsController < ApplicationController
  before_action :set_task
  before_action :set_item, only: %i[update destroy]

  def create
    @item = @task.checklist_items.new(item_params)
    authorize @item
    if @item.save
      redirect_to task_path(@task, anchor: "tab-detalhes"), notice: "Item adicionado."
    else
      redirect_to task_path(@task, anchor: "tab-detalhes"), alert: @item.errors.full_messages.to_sentence.presence || "Não foi possível adicionar o item."
    end
  end

  def update
    if @item.update(item_params)
      redirect_to task_path(@task, anchor: "tab-detalhes"), notice: "Item atualizado."
    else
      redirect_to task_path(@task, anchor: "tab-detalhes"), alert: @item.errors.full_messages.to_sentence.presence || "Não foi possível atualizar o item."
    end
  end

  def destroy
    @item.destroy
    redirect_to task_path(@task, anchor: "tab-detalhes"), notice: "Item removido."
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
    authorize @task, :show?
  end

  # Escopado pela tarefa da URL: item de outra tarefa → RecordNotFound (404), não vaza.
  def set_item
    @item = @task.checklist_items.find(params[:id])
    authorize @item
  end

  # Só content e completed são atribuíveis (task_id vem da URL; nada mais).
  def item_params
    params.require(:checklist_item).permit(:content, :completed)
  end
end
