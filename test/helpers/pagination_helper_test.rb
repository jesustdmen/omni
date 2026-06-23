require "test_helper"

# Paginação amigável (helper compartilhado): primeira/anterior/X-Y/próxima/última.
class PaginationHelperTest < ActionView::TestCase
  include PaginationHelper

  def url
    ->(p) { "/x?page=#{p}" }
  end

  test "renderiza status 'Página X de Y' com total e unidade" do
    html = pagination_nav(current: 2, total_pages: 5, total_count: 42, unit: "tarefa(s)", url: url)
    assert_includes html, "Página 2 de 5"
    assert_includes html, "42 tarefa(s)"
    assert_includes html, 'class="pagination__status"'
  end

  test "na primeira página: Primeira/Anterior desabilitados; Próxima/Última ativos" do
    html = pagination_nav(current: 1, total_pages: 3, total_count: 30, url: url)
    # desabilitados são <span class=... is-disabled>, não <a>
    assert_match(/<span[^>]*is-disabled[^>]*>« Primeira/, html)
    assert_match(/<span[^>]*is-disabled[^>]*>‹ Anterior/, html)
    assert_match(%r{<a[^>]*href="/x\?page=2"[^>]*>Próxima ›</a>}, html)
    assert_match(%r{<a[^>]*href="/x\?page=3"[^>]*>Última »</a>}, html)
  end

  test "na última página: Próxima/Última desabilitados; Primeira/Anterior ativos" do
    html = pagination_nav(current: 3, total_pages: 3, total_count: 30, url: url)
    assert_match(%r{<a[^>]*href="/x\?page=1"[^>]*>« Primeira</a>}, html)
    assert_match(%r{<a[^>]*href="/x\?page=2"[^>]*>‹ Anterior</a>}, html)
    assert_match(/<span[^>]*is-disabled[^>]*>Próxima ›/, html)
    assert_match(/<span[^>]*is-disabled[^>]*>Última »/, html)
  end

  test "no meio: todos os quatro botões são links" do
    html = pagination_nav(current: 2, total_pages: 4, total_count: 40, url: url)
    assert_equal 4, html.scan(/<a /).size
  end

  test "1 página com total_count: ainda renderiza o status (sem botões ativos)" do
    html = pagination_nav(current: 1, total_pages: 1, total_count: 3, unit: "item(ns)", url: url)
    assert_includes html, "Página 1 de 1"
    assert_equal 0, html.scan(/<a /).size # nada para navegar
  end

  test "1 página e sem total_count: não renderiza nada" do
    html = pagination_nav(current: 1, total_pages: 1, url: url)
    assert_equal "", html
  end

  test "aria-label padrão e customizável" do
    assert_includes pagination_nav(current: 1, total_pages: 2, total_count: 2, url: url), 'aria-label="Paginação"'
    assert_includes pagination_nav(current: 1, total_pages: 2, total_count: 2, url: url, aria: "Paginação dos turnos"), 'aria-label="Paginação dos turnos"'
  end
end
