module ConversationsHelper
  # F5.4 — status de vínculo da conversa para a lista de triagem.
  # Opera SOBRE a associação pré-carregada (includes(conversation_links: :task)) —
  # nenhuma query por linha. Sem html_safe/raw/sanitize: usa content_tag/link_to/safe_join.
  def link_status_badge(conversation)
    links = conversation.conversation_links.to_a
    return unlinked_badge(conversation) if links.empty?

    primary = links.find { |l| l.link_type == "primary" }
    mentions = links.count { |l| l.link_type == "mention" }

    if primary
      primary_badge(primary, mentions)
    else
      content_tag(:span, "Menção (#{mentions})", class: "badge badge--neutral")
    end
  end

  private

  def unlinked_badge(conversation)
    safe_join([
      content_tag(:span, "Sem vínculo", class: "badge badge--warning"),
      link_to("Criar tarefa", new_conversation_task_path(conversation), class: "btn btn--ghost btn--sm")
    ], " ")
  end

  def primary_badge(primary, mentions)
    badge = link_to(primary.task.title, primary.task,
                    class: "badge badge--info", title: "Tarefa primária")
    return badge if mentions.zero?

    safe_join([ badge, content_tag(:span, "+#{mentions} menção", class: "muted") ], " ")
  end
end
