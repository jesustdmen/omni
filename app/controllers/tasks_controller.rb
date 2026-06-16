class TasksController < ApplicationController
  before_action :set_task, only: %i[show edit update destroy]

  def index
    @tasks = policy_scope(Task).includes(:client, :project).order(created_at: :desc)
  end

  def show; end

  def new
    @task = Task.new
    authorize @task
  end

  def create
    @task = Task.new(task_params)
    authorize @task
    if @task.save
      redirect_to @task, notice: "Tarefa criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @task.update(task_params)
      redirect_to @task, notice: "Tarefa atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    redirect_to tasks_path, notice: "Tarefa removida."
  end

  private

  def set_task
    @task = Task.find(params[:id])
    authorize @task
  end

  def task_params
    params.require(:task).permit(:client_id, :project_id, :title, :description, :type, :status)
  end
end
