# PB-020e (Triagem) — classificação MANUAL de gaps na validação de tempo.
#
# `gap_kind` só se aplica a blocos `kind=gap` e é OBRIGATÓRIO para confirmar um gap
# (regra no model). Gap nunca entra no subtotal validado (não é cobrável). Lista
# permitida no banco (sem valor livre); `fora_vscode` NÃO é gap nesta fatia (trabalho
# fora do chat pode ser execução/evidência). Aditiva; NÃO cria TimeEntry/Task.
class AddGapKindToConversationWorkBlocks < ActiveRecord::Migration[8.1]
  def change
    add_column :conversation_work_blocks, :gap_kind, :text

    add_check_constraint :conversation_work_blocks,
                         "gap_kind IS NULL OR gap_kind IN ('pernoite', 'almoco', 'lanche', " \
                         "'outra_tarefa_cliente', 'aguardando_cliente', 'pausa', 'indeterminado')",
                         name: "conversation_work_blocks_gap_kind_check"
  end
end
