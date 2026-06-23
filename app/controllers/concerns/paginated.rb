# Paginação das listas operacionais: tamanho de página por allowlist + "Mostrar
# tudo" (com teto de segurança). Centraliza a sanitização para tasks/demands/
# projects/clients usarem a MESMA regra.
#
# Uso no controller:
#   include Paginated
#   PER_PAGE_OPTIONS = Paginated::PER_PAGE_OPTIONS   # (ou um próprio, se precisar)
#   @per_page = sanitized_per_page                    # Integer efetivo (cap quando "all")
#   @show_all = show_all_per_page?                     # para marcar a opção no select
module Paginated
  extend ActiveSupport::Concern

  included do
    if respond_to?(:helper_method)
      helper_method :per_page_select_options, :per_page_selected, :show_all_per_page?, :per_page_cap_notice
    end
  end

  PER_PAGE_OPTIONS = [ 10, 25, 50, 100 ].freeze
  DEFAULT_PER_PAGE = 50
  ALL_VALUE = "all".freeze
  # Teto de segurança para "Mostrar tudo": evita DoS acidental num dataset enorme.
  # O usuário assume a lentidão até esse limite; acima disso, ainda pagina.
  ALL_CAP = 1000

  # O usuário pediu "Mostrar tudo"?
  def show_all_per_page?
    params[:per_page].to_s == ALL_VALUE
  end

  # Tamanho efetivo da página (Integer). "all" → ALL_CAP; inválido → default.
  def sanitized_per_page(options: PER_PAGE_OPTIONS, default: DEFAULT_PER_PAGE)
    return ALL_CAP if show_all_per_page?

    n = params[:per_page].to_i
    options.include?(n) ? n : default
  end

  # Opções para o <select>: [["10/página",10], …, ["Mostrar tudo","all"]].
  def per_page_select_options(options: PER_PAGE_OPTIONS)
    options.map { |n| [ "#{n}/página", n ] } + [ [ "Mostrar tudo", ALL_VALUE ] ]
  end

  # Valor selecionado no <select> (o literal "all" quando for o caso).
  def per_page_selected
    show_all_per_page? ? ALL_VALUE : sanitized_per_page
  end

  # Aviso quando o usuário pediu "Mostrar tudo" mas há mais registros que o teto:
  # mostramos só ALL_CAP por segurança. Retorna a mensagem ou nil.
  def per_page_cap_notice(total_count)
    return nil unless show_all_per_page? && total_count.to_i > ALL_CAP

    "Mostrando os primeiros #{ALL_CAP} de #{total_count} — refine os filtros para ver o restante."
  end
end
