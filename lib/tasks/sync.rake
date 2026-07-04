namespace :sync do
  desc "F3.1 — importa summaries.jsonl (idempotente). Uso: bin/rails 'sync:summaries[caminho/para/summaries.jsonl]'"
  task :summaries, [ :path ] => :environment do |_task, args|
    path = args[:path].to_s
    abort("Informe o caminho do summaries.jsonl: bin/rails 'sync:summaries[/caminho/summaries.jsonl]'") if path.empty?

    # Entrada operacional simples: deriva titles/workspace do mesmo diretório, se existirem.
    dir = File.dirname(path)
    titles = File.join(dir, "session_titles.json")
    ws = File.join(dir, "workspace_maps.json")

    run = Sync::ImportSummaries.call(
      summaries_path: path,
      titles_path: (File.exist?(titles) ? titles : nil),
      workspace_maps_path: (File.exist?(ws) ? ws : nil)
    )

    puts "SyncRun #{run.id} — status=#{run.status} schema_version=#{run.schema_version}"
    puts "  lines_processed=#{run.lines_processed} imported=#{run.imported} " \
         "updated=#{run.updated} skipped=#{run.skipped} error_lines=#{run.error_lines}"
    puts "  conversations=#{Conversation.count} workspace_maps=#{WorkspaceMap.count} " \
         "(órfãos=#{WorkspaceMap.orphan.count})"
  end

  desc "F3.3 — resolve workspace_maps.folder a partir de <workspaceStorage>/<hash>/workspace.json " \
       "(read-only; atualiza só existentes). Uso: bin/rails 'sync:workspace_folders[/caminho/workspaceStorage]'"
  task :workspace_folders, [ :path ] => :environment do |_task, args|
    path = args[:path].to_s
    abort("Informe o caminho da pasta workspaceStorage") if path.empty?

    report = Sync::ResolveWorkspaceFolders.call(workspace_storage_path: path)

    puts "ResolveWorkspaceFolders — #{report.inspect}"
    puts "  workspace_maps=#{WorkspaceMap.count} (órfãos=#{WorkspaceMap.orphan.count})"
  end

  desc "Pré-F5 — constrói o índice de turnos (offsets) de sessions.jsonl (ADR-021; só ponteiros). " \
       "Uso: bin/rails 'sync:turn_refs[/caminho/sessions.jsonl]'"
  task :turn_refs, [ :path ] => :environment do |_task, args|
    path = args[:path].to_s
    abort("Informe o caminho do sessions.jsonl: bin/rails 'sync:turn_refs[/caminho/sessions.jsonl]'") if path.empty?

    r = Sync::BuildConversationTurnRefs.call(path: path)

    puts "BuildConversationTurnRefs — status=#{r.status}#{' (no-op)' if r.no_op} fingerprint=#{r.source_fingerprint}"
    puts "  lines_processed=#{r.lines_processed} refs_created=#{r.refs_created} refs_updated=#{r.refs_updated}"
    puts "  skipped_no_thread=#{r.skipped_no_thread} skipped_no_conversation=#{r.skipped_no_conversation} " \
         "skipped_telemetry=#{r.skipped_telemetry} malformed_lines=#{r.malformed_lines}"
    puts "  distinct_threads=#{r.distinct_threads} covered_conversations=#{r.covered_conversations}"
    puts "  turn_sources=#{TurnSource.count} conversation_turn_refs=#{ConversationTurnRef.count}"
  end

  desc "Incidente 2026-07-03 — DRY-RUN read-only: classifica as conversas do banco em " \
       "reais / contaminadas / fantasmas de telemetria / fantasmas com vínculo humano. " \
       "NÃO altera nada. Uso: bin/rails 'sync:integrity_report' (ou [caminho/summaries.jsonl])"
  task :integrity_report, [ :path ] => :environment do |_task, args|
    path = args[:path].presence || File.join(Rails.application.config.x.normalized_dir.to_s, "summaries.jsonl")

    # Evidência conversacional por thread_id, direto do arquivo normalizado (read-only).
    conversational_tids = {}
    if File.exist?(path)
      File.foreach(path) do |line|
        line = line.strip
        next if line.empty?

        parsed = JSON.parse(line) rescue next
        tid = parsed["thread_id"].to_s
        next if tid.empty?

        conversational_tids[tid] = true if Sync::Sources.conversational?(parsed["source"].to_s)
      end
    else
      puts "AVISO: #{path} não encontrado — classificação usará apenas o source do banco."
    end

    reais = []          # source do banco já é conversacional
    contaminadas = []   # source do banco é telemetria/nil, mas o arquivo tem fonte conversacional p/ o thread
    fantasmas = []      # sem evidência conversacional em lugar nenhum
    Conversation.find_each do |c|
      if Sync::Sources.conversational?(c.source)
        reais << c.id
      elsif conversational_tids[c.thread_id]
        contaminadas << c.id
      else
        fantasmas << c.id
      end
    end

    # Fantasmas com vínculo HUMANO (nunca deletar automaticamente).
    vinculo_humano = {}
    {
      "conversation_links" => ConversationLink, "triagens" => ConversationTriageDecision,
      "activity_drafts" => ConversationActivityDraft, "work_blocks" => ConversationWorkBlock,
      "time_entries" => TimeEntry
    }.each do |label, model|
      ids = model.where(conversation_id: fantasmas + contaminadas).distinct.pluck(:conversation_id)
      ids.each { |id| (vinculo_humano[id] ||= []) << label }
    end

    puts "sync:integrity_report — DRY-RUN (nada foi alterado)"
    puts "  summaries analisado: #{path} (thread_ids conversacionais no arquivo: #{conversational_tids.size})"
    puts "  conversas no banco:            #{Conversation.count}"
    puts "  ├─ reais (source conversacional):        #{reais.size}"
    puts "  ├─ reais CONTAMINADAS (reparo in-place): #{contaminadas.size}"
    puts "  └─ fantasmas só-telemetria:              #{fantasmas.size}"
    puts "  fantasmas/contaminadas com vínculo humano: #{vinculo_humano.size}"
    vinculo_humano.first(10).each { |id, labels| puts "    - #{id}: #{labels.join(', ')}" }
    puts "  refs atuais: #{ConversationTurnRef.count} (role=system: #{ConversationTurnRef.where(role: 'system').count})"
    puts "  Próxima etapa (SÓ com autorização): backup pg_dump → reimport corrigido → " \
         "remoção de fantasmas SEM vínculo humano → rebuild turn_refs."
  end
end
