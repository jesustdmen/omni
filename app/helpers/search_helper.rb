# PB-013 — apresentação dos resultados da busca global.
module SearchHelper
  # Destino do resultado (o card inteiro e o "Ir →" levam aqui).
  def search_result_path(record)
    case record
    when Task         then task_path(record)
    when Demand       then demand_path(record)
    when Project      then project_path(record)
    when Client       then client_path(record)
    when Contact      then client_path(record.client) # abre o cliente do contato
    when Conversation then conversation_path(record)
    end
  end

  # Badge do TIPO da entidade (leitura rápida).
  def search_type_badge(record)
    label = {
      "Task" => "Tarefa", "Demand" => "Demanda", "Project" => "Projeto",
      "Client" => "Cliente", "Contact" => "Contato", "Conversation" => "Conversa"
    }.fetch(record.class.name, record.class.name)
    tag.span(label, class: "badge badge--info search-result__type")
  end

  # Título principal do resultado.
  def search_result_title(record)
    case record
    when Conversation then record.title.presence || "— sem título —"
    else record.try(:name) || record.try(:title) || record.to_s
    end
  end

  # Contexto relacionado relevante (1 linha curta).
  def search_result_context(record)
    case record
    when Task     then "#{record.client.name} · #{record.status.to_s.humanize}"
    when Demand   then [ record.client&.name, record.status.to_s.humanize ].compact.join(" · ")
    when Project  then "#{record.client.name} · #{record.try(:status_label) || record.status}"
    when Client   then [ record.trade_name.presence, format_cnpj(record.cnpj) ].compact.join(" · ")
    when Contact  then [ record.client.name, record.email ].compact.join(" · ")
    when Conversation then [ status_badge(record.source), conversation_workspace_label(record) ].compact_blank.join(" ").html_safe
    end
  end

  # PB-013 — workspace da conversa (quando disponível); usa o mapa pré-carregado
  # no controller (@workspace_folders) p/ evitar N+1.
  def conversation_workspace_label(conversation)
    return if conversation.workspace_hash.blank?

    (@workspace_folders || {})[conversation.workspace_hash].presence
  end

  # aria-label contextual: "Ir para tarefa Corrigir relatório financeiro".
  def search_result_aria(record)
    type = { "Task" => "tarefa", "Demand" => "demanda", "Project" => "projeto",
             "Client" => "cliente", "Contact" => "contato", "Conversation" => "conversa" }
            .fetch(record.class.name, "registro")
    "Ir para #{type} #{search_result_title(record)}"
  end
end
