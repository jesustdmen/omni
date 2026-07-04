# PB-020e (Triagem) — subpágina de VALIDAÇÃO DE TEMPO da conversa (somente leitura).
# Exibe os blocos de trabalho (PB-020d) agrupados por data/turno com o SUBTOTAL
# VALIDADO (só execution+confirmed soma; gap confirmado é não cobrável; draft é
# pendente; discarded fica fora). As AÇÕES (confirmar/descartar/reabrir/classificar/
# atribuir) continuam no ConversationWorkBlocksController — esta tela NÃO cria
# TimeEntry, NÃO cria Task e NÃO altera ConversationLink.
class ConversationTimeValidationsController < ApplicationController
  def show
    @conversation = Conversation.find(params[:conversation_id])
    authorize @conversation, :show?

    # Conversa pessoal não participa da avaliação de trabalho (PB-020d): sem blocos,
    # sem subtotal. A view mostra a mensagem padrão e nada mais.
    return if @conversation.personal

    @validation = ConversationTimeValidation.call(conversation: @conversation)
    # Opções para atribuir cliente/tarefa a um bloco pendente (obrigatórios p/ validar).
    @clients = Client.ordered
    @tasks = Task.includes(:client).order(:title)
  end
end
