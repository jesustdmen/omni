# Command object: converte uma Demand em Task de forma ATÔMICA. PB-004c: a tarefa
# nasce VINCULADA pela `demand_id`; lock pessimista + revalidação pós-lock impedem
# que concorrência crie duas tarefas para a mesma demanda.
class ConvertDemand
  AlreadyConverted = Class.new(StandardError)

  Result = Struct.new(:ok, :task, :error, keyword_init: true) do
    def success?
      ok
    end
  end

  def self.call(demand)
    new(demand).call
  end

  def initialize(demand)
    @demand = demand
  end

  def call
    return failure("Demanda precisa de um cliente para converter.") if @demand.client_id.blank?

    task = nil
    ActiveRecord::Base.transaction do
      # Lock pessimista + REVALIDAÇÃO pós-lock: se outra transação converteu antes,
      # o reload aqui já vê status "converted" e abortamos sem criar tarefa.
      @demand.lock!
      raise AlreadyConverted if @demand.status == "converted"

      task = @demand.client.tasks.create!(
        project: nil,
        demand_id: @demand.id, # PB-004c — tarefa nasce vinculada à demanda de origem.
        title: @demand.title,
        description: @demand.description,
        type: "support",
        status: "pending"
      )
      @demand.update!(status: "converted", converted_at: Time.current)
    end

    success(task)
  rescue AlreadyConverted
    failure("Demanda já convertida.")
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    # Rollback total ao sair do bloco com exceção — sem commit parcial / sem 2ª tarefa.
    failure(e.message)
  end

  private

  def success(task)
    Result.new(ok: true, task: task, error: nil)
  end

  def failure(message)
    Result.new(ok: false, task: nil, error: message)
  end
end
