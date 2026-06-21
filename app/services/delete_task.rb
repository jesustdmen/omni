# PB-004c — exclusão de tarefa com ciclo coerente do vínculo demanda↔tarefa.
# Serviço EXPLÍCITO (sem callback oculto): se a tarefa foi originada por uma demanda,
# a demanda volta para "pending" (converted_at limpo) e a tarefa é excluída — tudo
# em transação única com lock. Tarefa sem demanda é excluída normalmente.
class DeleteTask
  Result = Struct.new(:ok, :error, keyword_init: true) do
    def success? = ok
  end

  def self.call(task)
    new(task).call
  end

  def initialize(task)
    @task = task
  end

  def call
    ActiveRecord::Base.transaction do
      @task.lock!
      demand = @task.origin_demand
      demand&.lock!

      # Excluir a tarefa primeiro libera a FK RESTRICT; depois devolve a demanda.
      @task.destroy!
      demand&.update!(status: "pending", converted_at: nil)
    end
    Result.new(ok: true, error: nil)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey => e
    Result.new(ok: false, error: e.message)
  end
end
