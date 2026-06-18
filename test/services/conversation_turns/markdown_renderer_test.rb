require "test_helper"

module ConversationTurns
  # F5.2 — markdown sanitizado (ADR-012). Cobre features de markdown + invariantes
  # de segurança (sem tag viva perigosa; links só http/https/mailto com rel/target;
  # raw HTML/scripts/handlers neutralizados; img bloqueada; PII redigida ANTES do markdown).
  class MarkdownRendererTest < ActiveSupport::TestCase
    R = ConversationTurns::MarkdownRenderer

    # --- features de markdown ---
    test "negrito" do
      assert_includes R.call("**b**"), "<strong>b</strong>"
    end

    test "itálico" do
      assert_includes R.call("*i*"), "<em>i</em>"
    end

    test "inline code" do
      assert_includes R.call("use `x`"), "<code>x</code>"
    end

    test "fenced code block" do
      html = R.call("```\ncode_here\n```")
      assert_includes html, "<pre>"
      assert_includes html, "<code>"
      assert_includes html, "code_here"
    end

    test "lista" do
      html = R.call("- a\n- b")
      assert_includes html, "<ul>"
      assert_includes html, "<li>a</li>"
    end

    test "heading sem âncora vazia" do
      assert_includes R.call("# Titulo"), "<h1>Titulo</h1>"
      assert_includes R.call("### Sub"), "<h3>Sub</h3>"
      assert_no_match(%r{<a\b[^>]*>\s*</a>}, R.call("# Titulo"))
    end

    test "blockquote" do
      assert_includes R.call("> cite"), "<blockquote>"
    end

    test "tabela GFM" do
      html = R.call("| a | b |\n|---|---|\n| 1 | 2 |")
      assert_includes html, "<table>"
      assert_includes html, "<td>1</td>"
    end

    # --- links ---
    test "link seguro recebe rel e target" do
      html = R.call("[x](https://a.com)")
      assert_includes html, 'href="https://a.com"'
      assert_includes html, 'rel="nofollow noopener noreferrer"'
      assert_includes html, 'target="_blank"'
    end

    test "link mailto é permitido" do
      assert_includes R.call("[m](mailto:a@b.com)"), 'href="mailto:a@b.com"'
    end

    test "link javascript: é removido (vira texto, sem href)" do
      html = R.call("[x](javascript:alert(1))")
      refute_includes html, "javascript:"
      assert_no_match(/<a\b[^>]*href/i, html)
      assert_includes html, "x"
    end

    test "link data: é removido" do
      html = R.call("[x](data:text/html,<b>)")
      refute_includes html, "data:text/html"
      assert_no_match(/<a\b[^>]*href/i, html)
    end

    # --- invariantes de segurança ---
    test "raw HTML é neutralizado (escapado, sem tag viva)" do
      html = R.call("<div onclick=x>hi</div>")
      assert_no_match(/<div/i, html)
      assert_includes html, "&lt;div"
    end

    test "<script> é neutralizado (sem tag viva)" do
      html = R.call("<script>alert(1)</script>")
      assert_no_match(/<script/i, html)
      assert_includes html, "&lt;script&gt;"
    end

    test "<img onerror> não vira tag viva" do
      assert_no_match(/<img/i, R.call("<img src=x onerror=alert(1)>"))
    end

    test "svg/onload não vira tag viva" do
      assert_no_match(/<svg/i, R.call("<svg onload=alert(1)>"))
    end

    test "imagem markdown remota é bloqueada (sem <img>)" do
      assert_no_match(/<img/i, R.call("![a](https://x/y.png)"))
    end

    test "nenhum atributo class/id/style/on* sobrevive" do
      html = R.call("[x](https://a.com)\n\n## H")
      assert_no_match(/\bclass=/, html)
      assert_no_match(/\bstyle=/, html)
      assert_no_match(/\bid=/, html)
      assert_no_match(/\bon\w+=/i, html)
    end

    # --- encadeamento PII → markdown ---
    test "PII é redigida antes do markdown (composição com PiiRedactor)" do
      red = ConversationTurns::PiiRedactor.call(
        "contato joao@example.com em /Users/jesus/p e token=abc123xyz"
      )
      html = R.call(red)
      refute_includes html, "joao@example.com"
      refute_includes html, "/Users/jesus"
      refute_includes html, "abc123xyz"
      refute_includes html, "mailto:joao" # e-mail redigido não vira autolink
      assert_includes html, "&lt;EMAIL&gt;"
      assert_includes html, "/Users/&lt;USER&gt;/p"
      assert_includes html, "token=&lt;SECRET&gt;"
    end

    # --- contrato de retorno ---
    test "retorna SafeBuffer html_safe" do
      assert_predicate R.call("**b**"), :html_safe?
    end

    test "blank/nil retorna vazio seguro" do
      assert_equal "", R.call("")
      assert_equal "", R.call(nil)
      assert_predicate R.call(""), :html_safe?
    end
  end
end
