require "test_helper"
require "tmpdir"
require "digest"

module ConversationTurns
  # Garante que o LazyLoader e o builder concordam no fingerprint do arquivo:
  # após indexar, o loader NÃO pode marcar o índice como :stale. Regressão da
  # PB-013b/sync: o loader usava partial_hash de 2 janelas (cabeça+cauda) enquanto
  # o builder grava 3 janelas (cabeça+MIOLO+cauda) — divergência marcava todo
  # índice válido como desatualizado e ocultava o conteúdo de TODA conversa.
  class LazyLoaderTest < ActiveSupport::TestCase
    setup do
      @dir = Dir.mktmpdir("sess")
      @path = File.join(@dir, "sessions.jsonl")
      @conv = Conversation.create!(thread_id: "ll-1", source: "x", title: "C", last_ts: Time.current)
    end

    teardown { FileUtils.remove_entry(@dir) if Dir.exist?(@dir) }

    def line(role: "user", ts: "2026-01-01T00:00:00+00:00", text: "oi", filler: "")
      { "thread_id" => "ll-1", "role" => role, "timestamp" => ts, "text" => text, "pad" => filler }
    end

    def write(lines)
      File.write(@path, lines.map { |h| JSON.generate(h) }.join("\n") + "\n")
    end

    test "após indexar, o loader lê os turnos (não fica :stale) — arquivo pequeno" do
      write([ line(text: "primeiro"), line(role: "assistant", text: "segundo") ])
      Sync::BuildConversationTurnRefs.call(path: @path)

      r = LazyLoader.call(conversation_id: @conv.id, path: @path)
      assert_equal :ok, r.status
      assert_equal 2, r.total
      assert_equal %w[primeiro segundo], r.turns.map(&:text)
      assert_equal 0, r.mismatched
    end

    test "após indexar, o loader lê os turnos — arquivo grande (>3 janelas, com miolo)" do
      # força o caminho cabeça+miolo+cauda (acima de HASH_WINDOW*3).
      big = "Z" * (Sync::BuildConversationTurnRefs::HASH_WINDOW * 2)
      write([ line(text: "alfa", filler: big), line(role: "assistant", text: "beta", filler: big) ])
      assert File.size(@path) > Sync::BuildConversationTurnRefs::HASH_WINDOW * 3

      Sync::BuildConversationTurnRefs.call(path: @path)
      r = LazyLoader.call(conversation_id: @conv.id, path: @path)
      assert_equal :ok, r.status, "loader não pode marcar índice recém-construído como :stale"
      assert_equal %w[alfa beta], r.turns.map(&:text)
    end

    test "partial_hash do loader == partial_hash do builder (mesmo content_hash)" do
      big = "Q" * (Sync::BuildConversationTurnRefs::HASH_WINDOW * 2)
      write([ line(filler: big) ])
      size = File.size(@path)

      builder_hash = Sync::BuildConversationTurnRefs.new(path: @path).send(:partial_hash, size)
      loader_hash  = LazyLoader.new(conversation_id: @conv.id, path: @path).send(:partial_hash, @path, size)
      assert_equal builder_hash, loader_hash
    end

    test "miolo alterado mantendo size e bordas torna o índice :stale (defesa preservada)" do
      head = "H" * (Sync::BuildConversationTurnRefs::HASH_WINDOW + 5)
      tail = "T" * (Sync::BuildConversationTurnRefs::HASH_WINDOW + 5)
      # arquivo válido p/ indexar (uma linha JSON), grande o bastante p/ 3 janelas
      write([ line(text: "x", filler: head + tail) ])
      Sync::BuildConversationTurnRefs.call(path: @path)
      assert_equal :ok, LazyLoader.call(conversation_id: @conv.id, path: @path).status

      # reescreve com MESMO tamanho mudando só 1 byte do miolo → fingerprint difere
      content = File.binread(@path)
      mid = content.bytesize / 2
      content[mid] = (content[mid] == "A" ? "B" : "A")
      File.binwrite(@path, content)

      assert_equal :stale, LazyLoader.call(conversation_id: @conv.id, path: @path).status
    end
  end
end
