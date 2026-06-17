# Command object: converte uma Demand em Task de forma ATÔMICA (corrige o gap
# não-transacional do RepoA). Não armazena FK demand↔task nesta fase (paridade).
class ConvertDemand
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
    return failure("Demanda já convertida.") if @demand.status == "converted"
    return failure("Demanda precisa de um cliente para converter.") if @demand.client_id.blank?

    task = nil
    ActiveRecord::Base.transaction do
      task = @demand.client.tasks.create!(
        project: nil,
        title: @demand.title,
        description: @demand.description,
        type: "support",
        status: "pending"
      )
      @demand.update!(status: "converted", converted_at: Time.current)
    end

    success(task)
  rescue ActiveRecord::RecordInvalid => e
    # A transação já fez rollback ao sair do bloco com exceção — sem commit parcial.
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
