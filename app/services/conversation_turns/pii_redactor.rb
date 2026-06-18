module ConversationTurns
  # F5.1.5 — redação CONSERVADORA de PII/segredos para conteúdo de turno exibido
  # read-only (text e tool_input). Opera sobre String, é idempotente e NÃO renderiza
  # HTML (o ERB continua auto-escapando). Não busca cobertura perfeita de todo segredo.
  #
  # Ordem importa: segredos rotulados (Bearer, key=value) antes de e-mail; paths por último.
  module PiiRedactor
    EMAIL = /[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i

    # "Bearer <token>" → "Bearer <SECRET>" (idempotente: <SECRET> não casa o char-class).
    BEARER = /\bBearer\s+[A-Za-z0-9._\-]+/i

    # chave sensível + ':'/'=' (com aspas/espaços opcionais, inclusive JSON) + valor.
    # Idempotente: "<SECRET>" começa com '<', que não pertence ao char-class do valor.
    SECRET_KEYS = /\b(api[_-]?key|access[_-]?token|refresh[_-]?token|secret|token|password|passwd|pwd)\b/i
    SECRET_KV = /#{SECRET_KEYS.source}("?\s*[:=]\s*"?)([^\s"'`,&}\)\]]+)/i

    # paths de usuário → mantém o prefixo, troca o nome por <USER>.
    # [^/\s"']+ exclui '<' implicitamente? não — então excluímos explicitamente via \z do token:
    USERS_UNIX   = %r{(/Users/)(?!<USER>)[^/\s"']+}i
    HOME_UNIX    = %r{(/home/)(?!<USER>)[^/\s"']+}i
    USERS_WIN_BS = %r{([A-Za-z]:\\Users\\)(?!<USER>)[^\\\s"']+}i
    USERS_WIN_FS = %r{([A-Za-z]:/Users/)(?!<USER>)[^/\s"']+}i

    module_function

    def call(value)
      return value if value.nil?

      s = value.to_s
      s = s.gsub(BEARER, "Bearer <SECRET>")
      s = s.gsub(SECRET_KV) { "#{Regexp.last_match(1)}#{Regexp.last_match(2)}<SECRET>" }
      s = s.gsub(EMAIL, "<EMAIL>")
      s = s.gsub(USERS_WIN_BS, '\1<USER>')
      s = s.gsub(USERS_WIN_FS, '\1<USER>')
      s = s.gsub(USERS_UNIX, '\1<USER>')
      s = s.gsub(HOME_UNIX, '\1<USER>')
      s
    end
  end
end
