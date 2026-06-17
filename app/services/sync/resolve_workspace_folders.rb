require "json"
require "cgi"

module Sync
  # F3.3 — resolve `workspace_maps.folder` a partir de `<workspaceStorage>/<hash>/workspace.json`.
  #
  # Exceção controlada ao ADR-008 (consumir só `output/normalized/`): lê APENAS o mapa
  # `workspace_hash → folder` da área `raw/.../workspaceStorage` (somente leitura). NÃO lê
  # conversas, turnos, `sessions.jsonl` ou shards, e NÃO executa o pipeline.
  #
  # Atualiza apenas WorkspaceMaps já existentes (não cria novos). Paths sob `Users/<nome>`
  # têm o usuário redigido (`<USER>`) antes de gravar.
  class ResolveWorkspaceFolders
    def self.call(workspace_storage_path:)
      new(workspace_storage_path: workspace_storage_path).call
    end

    def initialize(workspace_storage_path:)
      @base = workspace_storage_path.to_s
    end

    def call
      report = { scanned: 0, resolved: 0, updated: 0, unchanged: 0,
                 not_found_in_db: 0, skipped_without_folder: 0, errors: 0 }

      Dir.glob(File.join(@base, "*", "workspace.json")).sort.each do |file|
        report[:scanned] += 1
        hash = File.basename(File.dirname(file))

        parsed = parse(file)
        if parsed.nil?
          report[:errors] += 1
          next
        end

        folder = normalize_folder(parsed["folder"])
        if folder.blank?
          report[:skipped_without_folder] += 1
          next
        end

        wm = WorkspaceMap.find_by(workspace_hash: hash)
        if wm.nil?
          report[:not_found_in_db] += 1 # workspace sem conversa importada — não cria
          next
        end

        report[:resolved] += 1
        if wm.folder == folder
          report[:unchanged] += 1
        else
          wm.update!(folder: folder)
          report[:updated] += 1
        end
      end

      report
    end

    private

    def parse(file)
      parsed = JSON.parse(File.read(file))
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    # "file:///c%3A/AtivaLocal" -> "c:/AtivaLocal" (decodifica URI; remove a barra do drive).
    def normalize_folder(raw)
      return nil if raw.nil? || raw.to_s.strip.empty?

      path = raw.to_s.sub(%r{\Afile://}, "")
      path = CGI.unescape(path)
      path = path.sub(%r{\A/([A-Za-z]:)}, '\1')
      redact_home(path)
    end

    # Redige o usuário local em paths sob Users/<nome> ou home/<nome>.
    def redact_home(path)
      path
        .gsub(%r{(/Users/)[^/]+}i, '\1<USER>')
        .gsub(%r{(\\Users\\)[^\\]+}i, '\1<USER>')
        .gsub(%r{(/home/)[^/]+}i, '\1<USER>')
    end
  end
end
