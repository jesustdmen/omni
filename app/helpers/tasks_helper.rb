# PB-014 — apresentação do código legível de tarefa (TSK-000001).
module TasksHelper
  # "TSK-000001 — Título" (selects e rótulos de link). Inclui o cliente quando pedido.
  def task_code_label(task, with_client: false)
    base = [ task.code, task.title ].compact.join(" — ")
    return base unless with_client && task.respond_to?(:client) && task.client

    "#{base} (#{task.client.name})"
  end

  # Par [rótulo, id] para `options_for_select` em selects de tarefa.
  def task_select_option(task, with_client: true)
    [ task_code_label(task, with_client: with_client), task.id ]
  end

  # Badge/etiqueta só do código (para cabeçalhos/listas onde o título já aparece).
  def task_code_tag(task, css: "task-code muted")
    return if task.code.blank?

    tag.span(task.code, class: css)
  end
end
