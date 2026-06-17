namespace :tasks do
  desc "F4 — recalcula conversation_count/last_conversation_at por tarefa " \
       "(apenas vínculos primary; ignora conversas personal). Não cria links nem lê turnos/sessions/shards."
  task recount_conversations: :environment do
    processed = 0
    updated = 0

    Task.find_each do |task|
      before = [ task.conversation_count, task.last_conversation_at ]
      task.recompute_conversation_counters!
      processed += 1
      updated += 1 if [ task.reload.conversation_count, task.last_conversation_at ] != before
    end

    puts "Recount concluído: #{processed} tarefa(s) processada(s), #{updated} atualizada(s)."
  end
end
