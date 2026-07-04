module Sync
  # Contrato de FONTES do output normalizado (incidente de integridade 2026-07-03).
  #
  # O pipeline emite linhas de fontes CONVERSACIONAIS (conversa real) e de fontes de
  # TELEMETRIA/METADADO (`chat_editing_state` = telemetria de edição; `agent_sessions` =
  # cache de estado; `chat_session_index` = índice de títulos). As três reutilizam o
  # uuid da conversa como `thread_id` e podem aparecer em N workspaces — por isso
  # NUNCA criam/mesclam `Conversation` nem viram `conversation_turn_refs`.
  #
  # `thread_id` segue sendo a chave canônica da conversa, RESTRITA às fontes
  # conversacionais (medição 2026-07-03: 0 colisões multi-workspace nesse recorte).
  # Fonte desconhecida/ausente = NÃO conversacional (lista fechada: fonte nova do
  # pipeline exige decisão explícita aqui antes de virar conversa).
  module Sources
    CONVERSATIONAL = %w[
      chat_session_json chat_session_jsonl copilot_jsonl copilot_jsonl_raw
      codex_session claude_code_session openai_chatgpt
    ].freeze

    TELEMETRY = %w[chat_editing_state agent_sessions chat_session_index].freeze

    # Famílias: `json`/`jsonl`/copilot são REPRESENTAÇÕES da mesma sessão VS Code
    # (mesclam); famílias distintas com o mesmo thread_id não se mesclam em silêncio.
    FAMILIES = {
      "chat_session_json" => "vscode_chat",
      "chat_session_jsonl" => "vscode_chat",
      "copilot_jsonl" => "vscode_chat",
      "copilot_jsonl_raw" => "vscode_chat",
      "codex_session" => "codex",
      "claude_code_session" => "claude",
      "openai_chatgpt" => "openai"
    }.freeze

    def self.conversational?(source)
      CONVERSATIONAL.include?(source.to_s)
    end

    def self.family(source)
      FAMILIES[source.to_s]
    end
  end
end
