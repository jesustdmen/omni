require "test_helper"

# PB-014 — código legível de tarefa (TSK-000001) via sequence do Postgres.
class TaskCodeTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
  end

  def new_task(title = "T")
    Task.create!(client: @client, title: title, type: "support")
  end

  # --- formato ---------------------------------------------------------------

  test "code formata TSK + 6 dígitos zero-padded" do
    t = new_task
    assert_match(/\ATSK-\d{6}\z/, t.code)
    assert_equal "TSK-000001", Task.new(code_number: 1).code
    assert_equal "TSK-000042", Task.new(code_number: 42).code
    assert_equal "TSK-123456", Task.new(code_number: 123_456).code
  end

  test "code cresce além de 6 dígitos sem truncar" do
    assert_equal "TSK-1000000", Task.new(code_number: 1_000_000).code
  end

  test "code é nil quando code_number ausente (objeto não persistido sem default)" do
    assert_nil Task.new.code
  end

  # --- geração automática + unicidade ---------------------------------------

  test "toda tarefa nova recebe code_number automaticamente (sequence)" do
    t = new_task
    assert t.code_number.present?, "code_number deve vir da sequence do banco"
    assert t.code_number.positive?
  end

  test "code_number é sequencial e único entre criações" do
    a = new_task("A")
    b = new_task("B")
    assert_equal a.code_number + 1, b.code_number
    assert_not_equal a.code_number, b.code_number
  end

  test "fixtures/factory não precisam informar code_number" do
    # create! sem code_number funciona (default no banco) — requisito 6.
    assert_nothing_raised { new_task("sem código explícito") }
  end

  # --- read-only (não atribuível) -------------------------------------------

  test "code_number é attr_readonly: tentativa de alterar é bloqueada" do
    t = new_task
    original = t.code_number
    # Rails 8: atribuir um attr_readonly após persistido levanta ReadonlyAttributeError.
    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      t.update!(code_number: 999_999)
    end
    # update de OUTROS campos preserva o código.
    t.update!(title: "novo título")
    assert_equal original, t.reload.code_number
    assert_equal "novo título", t.title
  end

  test "code_number não está nos strong params do controller" do
    permitted = TasksController.new.send(:task_params) rescue nil
    # checagem direta na lista declarada (sem request): garante ausência.
    src = File.read(Rails.root.join("app/controllers/tasks_controller.rb"))
    assert_no_match(/permit\([^)]*code_number/, src)
  end

  # --- exclusão não reutiliza -----------------------------------------------

  test "excluir tarefa não reutiliza o código (sequence avança)" do
    a = new_task("A")
    b = new_task("B")
    b.destroy
    c = new_task("C")
    assert c.code_number > a.code_number, "novo código deve ser maior que os anteriores"
    assert_not_equal b.code_number, c.code_number, "código de tarefa excluída não é reusado"
  end

  # --- concorrência (sem duplicar sob inserções concorrentes) ----------------

  test "inserções concorrentes não duplicam code_number" do
    threads = 5.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Task.create!(client_id: @client.id, title: "C#{i}", type: "support").code_number
        end
      end
    end
    numbers = threads.map(&:value)
    assert_equal numbers.uniq.size, numbers.size, "code_number deve ser único sob concorrência"
  end

  # --- code_number_from (parser do termo de busca) ---------------------------

  test "code_number_from reconhece TSK-000001, tsk-1, número e ignora texto" do
    assert_equal 1, Task.code_number_from("TSK-000001")
    assert_equal 1, Task.code_number_from("tsk-1")
    assert_equal 5, Task.code_number_from("TSK000005")
    assert_equal 5, Task.code_number_from("  5  ")
    assert_equal 5, Task.code_number_from("0005")
    assert_nil Task.code_number_from("relatório")
    assert_nil Task.code_number_from("TSK-")
    assert_nil Task.code_number_from("50%")
    assert_nil Task.code_number_from("")
    assert_nil Task.code_number_from(nil)
  end
end
