module Ai
  # Monta um CONTEXTO TEXTUAL seguro e limitado da conversa para alimentar a IA local.
  #
  # Usa o mesmo mecanismo da tela (ConversationTurns::LazyLoader — ADR-021) e a mesma
  # redação de PII (ConversationTurns::PiiRedactor). Princípios:
  #   - conversa PESSOAL nunca vira contexto (privacidade — ADR-013);
  #   - se o índice estiver `:stale`/indisponível/vazio, retorna contexto VAZIO controlado;
  #   - só inclui turnos de usuário/assistente (ignora tool outputs);
  #   - redige PII, trunca por turno e limita o total (anti-vazamento e anti-DoS de prompt);
  #   - preserva ordem cronológica; conversa enorme → início + fim (seleção simples).
  #
  # O loader é injetável (`loader:`) só como costura de teste — a suíte não depende do
  # arquivo real nem do índice.
  class ConversationContextBuilder
    MAX_TURNS = 40            # nº máx de turnos incluídos no contexto
    MAX_TOTAL_CHARS = 15_000  # teto total de caracteres do contexto
    MAX_TURN_CHARS = 1_000    # teto por turno
    HEAD = 20                 # turnos do início (conversa grande)
    TAIL = 20                 # turnos do fim (conversa grande)
    LOAD_WINDOW = HEAD + TAIL # se total <= isso, carrega tudo (== MAX_TURNS: início+fim cabem)

    INCLUDED_ROLES = %w[user assistant].freeze
    ROLE_LABELS = { "user" => "usuário", "assistant" => "assistente" }.freeze

    Result = Struct.new(:text, :status, :turns_used, keyword_init: true) do
      def present? = text.to_s.strip.length.positive?
      def vazio? = !present?
    end

    def self.call(conversation:, loader: ConversationTurns::LazyLoader)
      new(conversation: conversation, loader: loader).call
    end

    def initialize(conversation:, loader: ConversationTurns::LazyLoader)
      @conversation = conversation
      @loader = loader
    end

    def call
      return vazio(:personal) if @conversation.personal

      turns = carregar_turnos
      return vazio(:indisponivel) if turns.nil? # :stale / :not_found / loader fora
      return vazio(:sem_texto) if turns.empty?

      montar(turns)
    end

    private

    # Carrega via o índice já usado pela app. Conversa grande: início + fim.
    def carregar_turnos
      primeiro = ler(limit: LOAD_WINDOW, offset: 0)
      return nil unless primeiro&.status == :ok

      total = primeiro.total.to_i
      return [] if total.zero?
      return Array(primeiro.turns) if total <= LOAD_WINDOW

      cabeca = Array(primeiro.turns).first(HEAD)
      cauda = ler(limit: TAIL, offset: total - TAIL)
      return nil unless cauda&.status == :ok

      cabeca + Array(cauda.turns)
    end

    # Filtra por papel no índice (user/assistant) — turnos de sistema/ferramenta não
    # entram no contexto; assim conversas dominadas por `system` ainda rendem trechos reais.
    def ler(limit:, offset:)
      @loader.call(conversation_id: @conversation.id, limit: limit, offset: offset, roles: INCLUDED_ROLES)
    end

    def montar(turns)
      blocos = []
      total_chars = 0

      turns.each do |turn|
        break if blocos.size >= MAX_TURNS

        papel = ROLE_LABELS[turn.role.to_s]
        next unless papel # só usuário/assistente

        texto = limpar(turn.text)
        next if texto.blank?

        bloco = "Turno #{turn.line_no} — #{papel}:\n#{texto}"
        break if total_chars + bloco.length > MAX_TOTAL_CHARS

        blocos << bloco
        total_chars += bloco.length
      end

      return vazio(:sem_texto) if blocos.empty?

      Result.new(text: blocos.join("\n\n"), status: :ok, turns_used: blocos.size)
    end

    # Redige PII (mesmo redator da tela) e trunca por turno.
    def limpar(text)
      limpo = ConversationTurns::PiiRedactor.call(text.to_s).to_s.strip
      return "" if limpo.empty?

      truncar(limpo, MAX_TURN_CHARS)
    end

    def truncar(str, limite)
      return str if str.length <= limite

      "#{str[0, limite]}… (truncado)"
    end

    def vazio(status)
      Result.new(text: "", status: status, turns_used: 0)
    end
  end
end
