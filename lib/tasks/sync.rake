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
end
