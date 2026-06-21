require "test_helper"
require "tmpdir"

module Sync
  # PB-015 — foco na correção do FALSO NO-OP do fingerprint (source_mtime na chave
  # do find_by + hash de cabeça/miolo/cauda). Usa fixtures pequenas (nunca 240 MB).
  class BuildConversationTurnRefsTest < ActiveSupport::TestCase
    setup do
      @dir = Dir.mktmpdir("sess")
      @path = File.join(@dir, "sessions.jsonl")
      # conversa real para os refs casarem (conv_map por thread_id)
      @conv = Conversation.create!(thread_id: "tt-1", source: "x", title: "C", last_ts: Time.current)
    end

    teardown { FileUtils.remove_entry(@dir) if Dir.exist?(@dir) }

    def write_sessions(lines)
      File.write(@path, lines.map { |h| JSON.generate(h) }.join("\n") + "\n")
    end

    def line(role: "user", ts: "2026-01-01T00:00:00+00:00", filler: "")
      { "thread_id" => "tt-1", "role" => role, "timestamp" => ts, "pad" => filler }
    end

    test "build cria refs e re-build idêntico é no-op" do
      write_sessions([ line, line(role: "assistant") ])
      r1 = Sync::BuildConversationTurnRefs.call(path: @path)
      assert_equal "ok", r1.status
      assert_not r1.no_op
      assert_equal 2, ConversationTurnRef.count

      r2 = Sync::BuildConversationTurnRefs.call(path: @path)
      assert r2.no_op, "mesmo arquivo deve ser no-op idempotente"
      assert_equal 2, ConversationTurnRef.count
    end

    test "miolo alterado mantendo size e bordas NÃO é falso no-op (hash de miolo detecta)" do
      # Duas versões com MESMO tamanho total: difere só um caractere no meio.
      big = "A" * 400_000
      write_sessions([ line(filler: big), line(role: "assistant", filler: big) ])
      r1 = Sync::BuildConversationTurnRefs.call(path: @path)
      assert_not r1.no_op
      hash1 = r1.source_fingerprint

      # reescreve com o MESMO número de bytes, mudando só o miolo do arquivo
      content = File.binread(@path)
      mid = content.bytesize / 2
      content[mid] = (content[mid] == "A" ? "B" : "A")
      File.binwrite(@path, content)
      assert_equal r1, r1 # (no-op guard de leitura)

      r2 = Sync::BuildConversationTurnRefs.call(path: @path)
      assert_not r2.no_op, "miolo diferente deve forçar rebuild (não falso no-op)"
      assert_not_equal hash1, r2.source_fingerprint
    end

    test "mtime diferente (mesmo conteúdo) força reverificação via find_by com source_mtime" do
      write_sessions([ line ])
      r1 = Sync::BuildConversationTurnRefs.call(path: @path)
      ts_old = r1.turn_source

      # toca o mtime (conteúdo igual) → o find_by inclui source_mtime, então não casa
      # o TurnSource anterior; reconstrói (mesmo fingerprint de conteúdo, novo mtime).
      future = ::Time.now + 120
      File.utime(future, future, @path)

      r2 = Sync::BuildConversationTurnRefs.call(path: @path)
      assert_not r2.no_op, "mtime diferente não deve cair em no-op"
      assert_not_equal ts_old.id, r2.turn_source.id
    end

    test "fingerprint inclui cabeça, miolo e cauda (arquivo grande)" do
      # cabeça e cauda iguais, miolo distinto → fingerprints distintas
      head = "H" * 70_000
      tail = "T" * 70_000
      File.binwrite(@path, head + "MID-A" + tail)
      fp_a = Sync::BuildConversationTurnRefs.new(path: @path).send(:fingerprint)[:content_hash]
      File.binwrite(@path, head + "MID-B" + tail)
      fp_b = Sync::BuildConversationTurnRefs.new(path: @path).send(:fingerprint)[:content_hash]
      assert_not_equal fp_a, fp_b
    end
  end
end
