# PB-007 — duplica um projeto de forma transacional. Copia APENAS campos autorizados:
# cliente, descrição e nome ("… (cópia)"). Status volta a "planning". NÃO copia
# orçamento, início/término, tarefas nem quaisquer vínculos. Falha → rollback total.
class DuplicateProject
  Result = Struct.new(:ok, :project, :error, keyword_init: true) do
    def success? = ok
  end

  def self.call(project)
    new(project).call
  end

  def initialize(project)
    @project = project
  end

  def call
    copy = nil
    ActiveRecord::Base.transaction do
      copy = Project.create!(
        client_id: @project.client_id,
        name: "#{@project.name} (cópia)",
        description: @project.description,
        status: "planning"
        # budget/start_date/end_date deliberadamente NÃO copiados.
      )
    end
    Result.new(ok: true, project: copy, error: nil)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(ok: false, project: nil, error: e.message)
  end
end
