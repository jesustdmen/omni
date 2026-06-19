class ConversationTasksController < ApplicationController
  # F5.3 (UI-10) — cria uma Task a partir de uma conversa e a vincula como
  # primary/manual na MESMA transação (sem tarefa órfã). Aninhado em
  # /conversations/:conversation_id/tasks. ADR-014 (domínio compartilhado).
  before_action :set_conversation

  def new
    authorize @conversation, :show?
    return redirect_with_primary_alert if conversation_has_primary?

    @task = Task.new(title: suggested_title)
  end

  def create
    authorize @conversation, :show?
    return redirect_with_primary_alert if conversation_has_primary?

    @task = Task.new(task_params)
    authorize @task, :create?
    @link = build_link
    authorize @link, :create?

    if persist
      redirect_to @task, notice: "Tarefa criada e vinculada à conversa."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  # Cria Task + ConversationLink atomicamente; em falha, rollback total (nenhuma
  # tarefa órfã). Erros de Task aparecem direto no form; erros do link sobem para
  # @task.errors[:base] para re-render do mesmo form.
  def persist
    ActiveRecord::Base.transaction do
      @task.save!
      @link.task = @task
      @link.save!
    end
    true
  rescue ActiveRecord::RecordInvalid
    @link.errors.full_messages.each { |m| @task.errors.add(:base, m) } if @task.errors.empty?
    false
  end

  # Standalone (não via @task.conversation_links) para não disparar autosave no @task.save!.
  def build_link
    ConversationLink.new(
      conversation: @conversation, task: @task,
      link_type: "primary", origin: "manual", created_by: current_user
    )
  end

  def conversation_has_primary?
    @conversation.conversation_links.where(link_type: "primary").exists?
  end

  def redirect_with_primary_alert
    redirect_to @conversation,
                alert: "Esta conversa já possui uma tarefa primária vinculada — remova o vínculo atual antes de criar outra."
  end

  def suggested_title
    @conversation.title.presence || "Conversa #{@conversation.thread_id.to_s.first(8)}"
  end

  def task_params
    params.require(:task).permit(:client_id, :project_id, :title, :description, :type, :status)
  end
end
