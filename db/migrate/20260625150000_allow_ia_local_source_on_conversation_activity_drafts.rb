# PB-020 (Triagem) — habilita a fonte `ia_local` para atividades de 2º nível.
#
# A IA local (Ollama/Gemma4) passa a poder SUGERIR atividades, gravadas sempre como
# RASCUNHO (status draft) com `source = 'ia_local'`. Aditiva: só AMPLIA o CHECK de
# `source` (mantém `manual` válido). Não recria a tabela nem altera dados existentes.
class AllowIaLocalSourceOnConversationActivityDrafts < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :conversation_activity_drafts,
                            name: "conversation_activity_drafts_source_check"
    add_check_constraint :conversation_activity_drafts,
                         "source IN ('manual', 'ia_local')",
                         name: "conversation_activity_drafts_source_check"
  end

  def down
    # Guarda: não dá para voltar ao CHECK antigo se já houver linhas `ia_local`.
    pendentes = exec_query(
      "SELECT COUNT(*) AS n FROM conversation_activity_drafts WHERE source = 'ia_local'"
    ).first["n"].to_i
    raise "Existem #{pendentes} atividades com source 'ia_local'; remova-as antes de reverter." if pendentes.positive?

    remove_check_constraint :conversation_activity_drafts,
                            name: "conversation_activity_drafts_source_check"
    add_check_constraint :conversation_activity_drafts,
                         "source IN ('manual')",
                         name: "conversation_activity_drafts_source_check"
  end
end
