require "test_helper"
require "json"
require "tmpdir"

module Sync
  class ResolveWorkspaceFoldersTest < ActiveSupport::TestCase
    # Cria uma pasta workspaceStorage sintética: { hash => conteúdo de workspace.json }.
    def build_storage(dir, entries)
      entries.each do |hash, content|
        sub = File.join(dir, hash)
        Dir.mkdir(sub)
        File.write(File.join(sub, "workspace.json"), content)
      end
    end

    test "resolve folders: decodifica URI, redige home, atualiza só existentes, ignora extras/nulos/malformado, idempotente" do
      WorkspaceMap.create!(workspace_hash: "h-ativa")
      WorkspaceMap.create!(workspace_hash: "h-home")
      WorkspaceMap.create!(workspace_hash: "h-nofolder")

      Dir.mktmpdir do |dir|
        build_storage(dir, {
          "h-ativa" => '{"folder":"file:///c%3A/AtivaLocal"}',
          "h-home" => '{"folder":"file:///c%3A/Users/Jesus/OneDrive/Documentos/Obsidian%20Vault"}',
          "h-nofolder" => "{}",
          "h-extra" => '{"folder":"file:///c%3A/Outro"}',
          "h-bad" => "{ quebrado"
        })

        report = Sync::ResolveWorkspaceFolders.call(workspace_storage_path: dir)

        assert_equal 5, report[:scanned]
        assert_equal 2, report[:resolved]
        assert_equal 2, report[:updated]
        assert_equal 0, report[:unchanged]
        assert_equal 1, report[:not_found_in_db]
        assert_equal 1, report[:skipped_without_folder]
        assert_equal 1, report[:errors]

        # decodificação de URI file:
        assert_equal "c:/AtivaLocal", WorkspaceMap.find_by!(workspace_hash: "h-ativa").folder
        # redação de home/usuário
        assert_equal "c:/Users/<USER>/OneDrive/Documentos/Obsidian Vault",
                     WorkspaceMap.find_by!(workspace_hash: "h-home").folder
        # workspace.json sem folder → pulado (permanece órfão)
        assert_nil WorkspaceMap.find_by!(workspace_hash: "h-nofolder").folder
        # extra (sem linha no DB) NÃO é criado
        assert_nil WorkspaceMap.find_by(workspace_hash: "h-extra")

        # idempotência: 2ª execução não altera nada
        report2 = Sync::ResolveWorkspaceFolders.call(workspace_storage_path: dir)
        assert_equal 0, report2[:updated]
        assert_equal 2, report2[:unchanged]
        assert_equal "c:/AtivaLocal", WorkspaceMap.find_by!(workspace_hash: "h-ativa").folder
      end
    end
  end
end
