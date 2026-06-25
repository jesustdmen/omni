require "json"

module Ai
  # Serviço de SUGESTÃO de atividades de 2º nível a partir de uma conversa.
  #
  # Usa o CONTEXTO TEXTUAL real e seguro da conversa (Ai::ConversationContextBuilder —
  # LazyLoader + PiiRedactor) como fonte principal; metadados são só apoio. Pede ao
  # Ollama uma resposta JSON e devolve uma PROPOSTA EM MEMÓRIA — nada é gravado.
  #
  # Regras de produto (ver docs/PB-020 e docs/ia_local_ollama_gemma4_api.md):
  #   - a IA SUGERE; o humano CONFIRMA;
  #   - extrai atividades EXPLÍCITAS dos trechos; não inventa a partir de contadores;
  #   - NÃO cria/edita ConversationActivityDraft, Task, TimeEntry nem ConversationLink;
  #   - conversa pessoal / contexto insuficiente ⇒ não chama a IA (resultado sem contexto);
  #   - falha da IA NÃO levanta exceção: retorna resultado vazio com `erro` preenchido.
  class SuggestConversationActivities
    CONFIANCAS = %w[baixa media alta].freeze
    CONFIANCA_PADRAO = "media"
    MAX_ATIVIDADES = 5

    # Títulos meta (sobre a própria conversa) que nunca são atividades válidas.
    PADROES_GENERICOS = [
      /analis\w+ a conversa/i,
      /audit\w+ a (comunica|conversa)/i,
      /revis\w+ da conversa/i,
      /resum\w+ a conversa/i
    ].freeze

    Atividade = Struct.new(:titulo, :descricao, :evidencia, :confianca, keyword_init: true)

    # `erro` preenchido = falha da IA; `sem_contexto` = não havia texto seguro p/ enviar.
    Result = Struct.new(:objetivo_principal, :atividades, :resposta_bruta, :erro, :sem_contexto, keyword_init: true) do
      def sucesso? = erro.nil? && !sem_contexto?
      def falhou? = !erro.nil?
      def sem_contexto? = sem_contexto == true
      def vazio? = atividades.empty? && objetivo_principal.to_s.strip.empty?
    end

    def self.call(conversation:, client: Ai::OllamaClient.new, context_builder: Ai::ConversationContextBuilder)
      new(conversation: conversation, client: client, context_builder: context_builder).call
    end

    def initialize(conversation:, client: Ai::OllamaClient.new, context_builder: Ai::ConversationContextBuilder)
      @conversation = conversation
      @client = client
      @context_builder = context_builder
    end

    def call
      contexto = @context_builder.call(conversation: @conversation)
      return resultado_sem_contexto if contexto.vazio?

      raw = @client.chat(messages: mensagens(contexto.text), format: "json")
      parsed = JSON.parse(raw.to_s)
      montar_resultado(parsed, raw)
    rescue Ai::OllamaClient::Error => e
      resultado_vazio(erro: e.message)
    rescue JSON::ParserError => e
      resultado_vazio(erro: "Resposta da IA não é JSON válido: #{e.message}", resposta_bruta: raw)
    end

    private

    def montar_resultado(parsed, raw)
      unless parsed.is_a?(Hash)
        return resultado_vazio(erro: "Formato inesperado da IA (esperado objeto JSON).", resposta_bruta: raw)
      end

      objetivo = parsed["objetivo_principal"].to_s.strip
      atividades = Array(parsed["atividades"])
                   .filter_map { |item| normalizar_atividade(item) }
                   .first(MAX_ATIVIDADES)

      Result.new(objetivo_principal: objetivo.presence, atividades: atividades, resposta_bruta: raw, erro: nil)
    end

    # Descarta: item sem título, SEM evidência preenchida, ou título meta/genérico.
    # Confiança inválida/ausente → padrão (media).
    def normalizar_atividade(item)
      return nil unless item.is_a?(Hash)

      titulo = item["titulo"].to_s.strip
      return nil if titulo.empty? || generico?(titulo)

      evidencia = item["evidencia"].to_s.strip
      return nil if evidencia.empty? # exige evidência textual

      Atividade.new(
        titulo: titulo,
        descricao: item["descricao"].to_s.strip.presence,
        evidencia: evidencia,
        confianca: normalizar_confianca(item["confianca"])
      )
    end

    def generico?(titulo)
      PADROES_GENERICOS.any? { |re| titulo.match?(re) }
    end

    def normalizar_confianca(value)
      v = value.to_s.strip.downcase
      CONFIANCAS.include?(v) ? v : CONFIANCA_PADRAO
    end

    def resultado_vazio(erro:, resposta_bruta: nil)
      Result.new(objetivo_principal: nil, atividades: [], resposta_bruta: resposta_bruta, erro: erro)
    end

    def resultado_sem_contexto
      Result.new(objetivo_principal: nil, atividades: [], resposta_bruta: nil, erro: nil, sem_contexto: true)
    end

    def mensagens(trechos)
      [
        { role: "system", content: prompt_sistema },
        { role: "user", content: prompt_usuario(trechos) }
      ]
    end

    # Conduta da IA (PT-BR): extrair atividades REAIS dos trechos; nunca de metadados.
    def prompt_sistema
      <<~TEXTO.strip
        Você é o assistente de triagem operacional do Omni.
        Sua tarefa é EXTRAIR atividades reais de 2º nível que aconteceram ou foram
        explicitamente discutidas nos TRECHOS da conversa. Você apenas sugere; a
        confirmação é SEMPRE humana.

        Fonte:
        - use os TRECHOS da conversa como fonte PRINCIPAL; os metadados são só apoio;
        - NÃO use apenas metadados/contadores para criar atividade.

        O que fazer:
        - extraia no máximo #{MAX_ATIVIDADES} atividades de 2º nível, com granularidade
          intermediária (nem genéricas demais, nem detalhadas demais);
        - cada atividade deve CITAR uma evidência curta retirada dos trechos enviados;
        - responda APENAS com um JSON válido (sem nenhum texto fora do JSON);
        - confiança deve ser um destes valores: #{CONFIANCAS.join(', ')}.

        O que NÃO fazer:
        - atividade NÃO é Task formal, subtarefa oficial nem checklist oficial;
        - atividade NÃO é TimeEntry; NÃO estime duração, horas, prazo, data, valor ou cobrança;
        - NÃO crie atividades sobre "analisar a conversa" ou "auditar a comunicação";
        - NÃO crie atividades genéricas de documentação, revisão ou otimização sem evidência textual;
        - NÃO invente: se a evidência textual não existir, NÃO crie a atividade.

        Sem evidência textual suficiente: retorne a lista de atividades VAZIA.
      TEXTO
    end

    def prompt_usuario(trechos)
      <<~TEXTO.strip
        Metadados (apoio — não use sozinhos):
        #{contexto_metadados.join("\n")}

        Trechos da conversa (fonte principal):
        #{trechos}

        Responda APENAS com um JSON neste formato:
        {
          "objetivo_principal": "string curta",
          "atividades": [
            { "titulo": "string", "descricao": "string", "evidencia": "string", "confianca": "baixa|media|alta" }
          ]
        }

        Exemplo de resposta (ilustrativo):
        {
          "objetivo_principal": "Padronizar a documentação dos módulos fiscais",
          "atividades": [
            {
              "titulo": "Revisar a documentação dos módulos fiscais",
              "descricao": "Conferir e padronizar os documentos citados nos trechos.",
              "evidencia": "Turno 13 — assistente: ajustes na documentação dos módulos fiscais.",
              "confianca": "media"
            }
          ]
        }

        Se os trechos acima não evidenciarem atividades reais, responda com
        "atividades": [] (lista vazia). Não invente atividades.
      TEXTO
    end

    def contexto_metadados
      arquivos = Array(@conversation.files_changed)
      [
        "Título da conversa: #{valor(@conversation.title)}",
        "Workspace: #{valor(workspace_label)}",
        "Período: #{periodo}",
        "Mensagens: #{@conversation.message_count}",
        "Turnos do usuário: #{@conversation.user_turns}",
        "Turnos do assistente: #{@conversation.assistant_turns}",
        "Chamadas de ferramenta (tool calls): #{@conversation.tool_calls}",
        "Arquivos alterados: #{arquivos.any? ? arquivos.join(', ') : '—'}"
      ]
    end

    def workspace_label
      return nil if @conversation.workspace_hash.blank?

      folder = WorkspaceMap.find_by(workspace_hash: @conversation.workspace_hash)&.folder
      folder.presence || @conversation.workspace_hash
    end

    def periodo
      return "—" unless @conversation.first_ts || @conversation.last_ts

      "#{formatar_ts(@conversation.first_ts)} → #{formatar_ts(@conversation.last_ts)}"
    end

    def formatar_ts(ts)
      ts ? ts.iso8601 : "—"
    end

    def valor(v)
      v.to_s.strip.presence || "—"
    end
  end
end
