# PB-013b — mecanismo central e único de preservação de contexto (`return_to`).
# Sanitiza um caminho de retorno: aceita SOMENTE caminho interno absoluto
# (inicia com "/"), preservando query string e fragmento interno; rejeita
# qualquer coisa com scheme/host, "//host", backslash, CR/LF, controle ou
# tamanho excessivo. Nunca redireciona para origem externa.
#
# Uso típico:
#   redirect_to safe_return_to(fallback: tasks_path)   # nos controllers
#   return_to_param                                     # repassar em links/forms (view)
module ReturnNavigation
  extend ActiveSupport::Concern

  MAX_LEN = 2000

  included do
    helper_method :return_to_param, :safe_return_to if respond_to?(:helper_method)
  end

  # Valor sanitizado para repasse (string segura ou nil). Aceita um candidato
  # explícito; por padrão usa params[:return_to].
  def return_to_param(candidate = nil)
    sanitize_internal_path(candidate || params[:return_to])
  end

  # Caminho de destino final: o return_to sanitizado OU o fallback do recurso.
  # `current:` evita redirecionar para a própria página (anti-loop) quando dado.
  def safe_return_to(fallback:, candidate: nil, current: nil)
    path = sanitize_internal_path(candidate || params[:return_to])
    return fallback if path.nil?
    return fallback if current.present? && same_path?(path, current)

    path
  end

  # Fallback de "Voltar" baseado no referer interno (mecanismo SECUNDÁRIO — só
  # quando não há return_to explícito). Mantém o comportamento da PB-013a.
  def safe_referer_back(fallback: nil)
    fallback ||= respond_to?(:root_path) ? root_path : "/"
    referer = request.referer
    return fallback if referer.blank?

    uri = URI.parse(referer)
    return fallback unless uri.host == request.host && uri.port == request.port
    return fallback if uri.path == request.path # anti-loop: veio da própria página

    sanitize_internal_path([ uri.path, uri.query ].compact.join("?")) || fallback
  rescue URI::InvalidURIError
    fallback
  end

  private

  # Núcleo da sanitização. Retorna a string segura ou nil.
  def sanitize_internal_path(raw)
    value = raw.to_s
    return nil if value.blank? || value.length > MAX_LEN
    return nil if value.match?(/[\x00-\x1f\x7f]/)      # controle, inclui CR/LF/TAB
    return nil if value.include?("\\")                  # backslash (ex.: /\evil)
    return nil unless value.start_with?("/")            # precisa ser path absoluto interno
    return nil if value.start_with?("//")               # "//host" → protocolo-relativo

    # Não pode haver scheme/host: parseia e confirma que é caminho puro.
    uri = URI.parse(value)
    return nil if uri.scheme.present? || uri.host.present?
    return nil unless uri.path.to_s.start_with?("/")

    # Reconstrói só path?query#fragment (descarta qualquer userinfo/host residual).
    out = uri.path
    out += "?#{uri.query}" if uri.query.present?
    out += "##{uri.fragment}" if uri.fragment.present?
    out
  rescue URI::InvalidURIError
    nil
  end

  def same_path?(a, b)
    a.to_s.split("#").first == b.to_s.split("#").first
  end
end
