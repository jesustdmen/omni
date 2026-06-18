module ConversationTurns
  # F5.2 — render de markdown (GFM) do `text` de turno para HTML SEGURO (ADR-012).
  # Único lugar do projeto autorizado a produzir HTML (`html_safe`) de conteúdo de
  # conversa. Pipeline (defesa em profundidade):
  #   1. commonmarker em modo SEGURO (unsafe:false → HTML cru da fonte é escapado/omitido);
  #   2. Rails::HTML5::SafeListSanitizer com allowlist restrita (tags/atributos);
  #   3. hardening de links (só http/https/mailto; rel/target forçados; demais href removidos).
  # NÃO trata `tool_input` (esse segue como texto em <pre>). NÃO faz redação de PII —
  # o chamador (componente) redige ANTES de chamar este renderer.
  module MarkdownRenderer
    ALLOWED_TAGS = %w[
      p br hr strong em b i del code pre blockquote
      ul ol li h1 h2 h3 h4 h5 h6 a
      table thead tbody tr th td
    ].freeze
    ALLOWED_ATTRS = %w[href rel target].freeze
    SAFE_LINK = /\A(?:https?:|mailto:)/i
    LINK_REL = "nofollow noopener noreferrer".freeze

    MD_OPTIONS = {
      # unsafe:false → não confia em HTML embutido; escape:true → HTML cru da fonte
      # (e marcadores de redação como <EMAIL>) é ESCAPADO (visível e inerte), não descartado.
      render: { unsafe: false, escape: true, hardbreaks: false },
      extension: { table: true, strikethrough: true, autolink: true, tagfilter: true }
    }.freeze

    module_function

    def call(text)
      return "".html_safe if text.blank?

      raw_html = Commonmarker.to_html(text.to_s, options: MD_OPTIONS)
      allowlisted = Rails::HTML5::SafeListSanitizer.new.sanitize(
        raw_html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRS
      )
      harden_links(allowlisted).html_safe
    end

    # Links: só http/https/mailto recebem rel/target; os demais (e âncoras vazias,
    # ex.: heading-anchors) são desembrulhados (viram texto) — sem href inseguro.
    def harden_links(html)
      fragment = Loofah.html5_fragment(html)
      fragment.css("a").each do |node|
        if node["href"].to_s.match?(SAFE_LINK)
          node.attribute_nodes.each { |attr| node.remove_attribute(attr.name) unless attr.name == "href" }
          node["rel"] = LINK_REL
          node["target"] = "_blank"
        else
          node.replace(node.children)
        end
      end
      fragment.to_html
    end
  end
end
