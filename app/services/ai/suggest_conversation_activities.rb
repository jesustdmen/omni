require "json"

module Ai
  # Serviço de SUGESTÃO de atividades de 2º nível a partir de uma conversa.
  #
  # Monta um prompt em PT-BR com os dados JÁ disponíveis (objeto Conversation +
  # workspace resolvido), pede ao Ollama uma resposta JSON e devolve uma PROPOSTA
  # EM MEMÓRIA — nada é gravado.
  #
  # Regras de produto (ver docs/PB-020 e docs/ia_local_ollama_gemma4_api.md):
  #   - a IA SUGERE; o humano CONFIRMA;
  #   - a sugestão vira, no máximo, proposta em memória nesta fatia;
  #   - NÃO cria/edita ConversationActivityDraft, Task, TimeEntry nem ConversationLink;
  #   - NÃO lê sessions.jsonl nem qualquer arquivo bruto;
  #   - falha da IA NÃO levanta exceção para o chamador: retorna resultado vazio com
  #     `erro` preenchido (degradação graciosa — a Triagem manual segue normal).
  class SuggestConversationActivities
    # Lista permitida de confiança; valor fora da lista é normalizado para o padrão.
    CONFIANCAS = %w[baixa media alta].freeze
    CONFIANCA_PADRAO = "media"
    # Teto de atividades de 2º nível por conversa (também reforçado no prompt).
    MAX_ATIVIDADES = 5

    # Uma atividade sugerida (proposta em memória; chave interna em inglês para Struct).
    Atividade = Struct.new(:titulo, :descricao, :evidencia, :confianca, keyword_init: true)

    # Resultado da sugestão. `erro` nil = sucesso; preenchido = falha controlada.
    Result = Struct.new(:objetivo_principal, :atividades, :resposta_bruta, :erro, keyword_init: true) do
      def sucesso? = erro.nil?
      def falhou? = !sucesso?
      def vazio? = atividades.empty? && objetivo_principal.to_s.strip.empty?
    end

    def self.call(conversation:, client: Ai::OllamaClient.new)
      new(conversation: conversation, client: client).call
    end

    def initialize(conversation:, client: Ai::OllamaClient.new)
      @conversation = conversation
      @client = client
    end

    def call
      raw = @client.chat(messages: mensagens, format: "json")
      parsed = JSON.parse(raw.to_s)
      montar_resultado(parsed, raw)
    rescue Ai::OllamaClient::Error => e
      # IA indisponível/erro de transporte → sem sugestão, sem explodir.
      resultado_vazio(erro: e.message)
    rescue JSON::ParserError => e
      # Modelo respondeu algo que não é JSON → tratamos como "sem sugestão".
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

    # Item sem título não é atividade útil → descartado. Confiança inválida → padrão.
    def normalizar_atividade(item)
      return nil unless item.is_a?(Hash)

      titulo = item["titulo"].to_s.strip
      return nil if titulo.empty?

      Atividade.new(
        titulo: titulo,
        descricao: item["descricao"].to_s.strip.presence,
        evidencia: item["evidencia"].to_s.strip.presence,
        confianca: normalizar_confianca(item["confianca"])
      )
    end

    # Regra clara: confiança fora da lista permitida vira CONFIANCA_PADRAO (media).
    def normalizar_confianca(value)
      v = value.to_s.strip.downcase
      CONFIANCAS.include?(v) ? v : CONFIANCA_PADRAO
    end

    def resultado_vazio(erro:, resposta_bruta: nil)
      Result.new(objetivo_principal: nil, atividades: [], resposta_bruta: resposta_bruta, erro: erro)
    end

    def mensagens
      [
        { role: "system", content: prompt_sistema },
        { role: "user", content: prompt_usuario }
      ]
    end

    # Regras de conduta da IA (em PT-BR): sugerir, não decidir, não inventar.
    def prompt_sistema
      <<~TEXTO.strip
        Você é um assistente que SUGERE atividades de trabalho a partir de uma conversa técnica.
        Regras obrigatórias:
        - você apenas SUGERE; a confirmação é sempre humana;
        - NÃO invente dados que não estejam no contexto informado;
        - responda APENAS com um JSON válido (sem texto fora do JSON);
        - no máximo #{MAX_ATIVIDADES} atividades;
        - as atividades devem ser de 2º nível: nem genéricas demais, nem detalhadas demais;
        - confiança deve ser um destes valores: #{CONFIANCAS.join(', ')}.
      TEXTO
    end

    # Contexto factual (só dados disponíveis) + contrato de saída esperado.
    def prompt_usuario
      <<~TEXTO.strip
        Dados da conversa (use apenas o que está aqui; não invente):
        #{contexto.join("\n")}

        Responda APENAS com um JSON neste formato:
        {
          "objetivo_principal": "string curta",
          "atividades": [
            { "titulo": "string", "descricao": "string", "evidencia": "string", "confianca": "baixa|media|alta" }
          ]
        }
      TEXTO
    end

    def contexto
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

    # Folder resolvido pelo workspace (quando houver); senão o hash; senão "—".
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
