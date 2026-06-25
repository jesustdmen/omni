class ConversationsController < ApplicationController
  include Paginated # lista de conversas: tamanho por allowlist + "Mostrar tudo"
  # F3.UI.1 — console SOMENTE LEITURA de validação da Fase 3.
  PER_PAGE = 50
  # F5.1 — turnos read-only por página. PB-paginação: o operador pode escolher o
  # tamanho da página numa allowlist fixa (sem "todos" irrestrito — conversas têm
  # centenas de turnos com markdown; carregar tudo travaria o render).
  TURNS_PER_PAGE = 50
  TURNS_PER_PAGE_OPTIONS = [ 50, 100, 200 ].freeze

  def index
    scope = filtered(policy_scope(Conversation))

    @total_count = scope.count
    @per_page = sanitized_per_page
    @show_all = show_all_per_page?
    @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
    @page = [ [ params[:page].to_i, 1 ].max, @total_pages ].min
    # F5.4 — eager load de vínculos+task APENAS na página (evita N+1 dos badges;
    # @total_count fica sem includes). Turnos NÃO são carregados aqui.
    @conversations = scope
      .includes(conversation_links: :task)
      .order(Arel.sql("last_ts DESC NULLS LAST, updated_at DESC"))
      .limit(@per_page)
      .offset((@page - 1) * @per_page)

    load_kpis
    @sources = Conversation.distinct.pluck(:source).compact.sort
    @folders = WorkspaceMap.pluck(:workspace_hash, :folder).to_h
  end

  def show
    @conversation = Conversation.find(params[:id])
    authorize @conversation
    @folder = WorkspaceMap.find_by(workspace_hash: @conversation.workspace_hash)&.folder
    # F4 — vínculos da conversa + tarefas disponíveis para o form de vínculo manual.
    @links = @conversation.conversation_links.includes(:created_by, task: :client).order(:created_at)
    @has_primary = @links.any? { |l| l.link_type == "primary" }
    @tasks = Task.includes(:client).order(:title)
    @return_to = return_to_param # PB-013b — origem (lista/busca) p/ "Voltar".
    load_turns
    load_triage if triage_mode?
  end

  private

  # PB-020 (Triagem) — modo triagem da conversa via ?mode=triage (vindo da Inbox).
  # Read-only: estado derivado, cliente sugerido e gaps visuais; sem persistência.
  def triage_mode?
    params[:mode] == "triage"
  end
  helper_method :triage_mode?

  def load_triage
    @triage = ConversationTriage.derive(@conversation)        # estado + cliente sugerido
    @timeline = ConversationTimeline.call(conversation: @conversation) # gaps (do índice ts)
  end

  # F5.1 — leitura lazy read-only dos turnos (ADR-021/ADR-012).
  # b1: conversa pessoal (ADR-013) não chama o loader — conteúdo oculto nesta fatia.
  # limit é FIXO (TURNS_PER_PAGE); offset deriva da página (sem limit/offset do usuário).
  def load_turns
    @turns_hidden_personal = @conversation.personal
    return if @turns_hidden_personal

    @turn_per_page = sanitized_turn_per_page
    @turn_page = [ params[:turn_page].to_i, 1 ].max
    offset = (@turn_page - 1) * @turn_per_page
    @turns = ConversationTurns::LazyLoader.call(
      conversation_id: @conversation.id, limit: @turn_per_page, offset: offset
    )
    @turn_total_pages = [ (@turns.total.to_f / @turn_per_page).ceil, 1 ].max
    # página fora do intervalo → recalcula (ex.: trocar per_page reduz total de páginas).
    @turn_page = [ @turn_page, @turn_total_pages ].min
  end

  # Tamanho da página de turnos: só valores da allowlist; inválido → default.
  def sanitized_turn_per_page
    n = params[:turn_per_page].to_i
    TURNS_PER_PAGE_OPTIONS.include?(n) ? n : TURNS_PER_PAGE
  end

  # Conjunto pequeno (≤ total de workspace_maps) de hashes com folder resolvido.
  def resolved_hashes
    @resolved_hashes ||= WorkspaceMap.where.not(folder: nil).pluck(:workspace_hash)
  end

  def filtered(scope)
    scope = scope.where(source: params[:source]) if params[:source].present?

    case params[:title]
    when "with" then scope = scope.where.not(title: nil)
    when "without" then scope = scope.where(title: nil)
    end

    case params[:folder]
    when "with" then scope = scope.where(workspace_hash: resolved_hashes)
    when "orphan" then scope = scope.where.not(workspace_hash: resolved_hashes)
    end

    # F5.4 — filtro por status de vínculo (subquery em coluna indexada; sem JOIN duplicado).
    case params[:link]
    when "none" then scope = scope.where.missing(:conversation_links)
    when "primary" then scope = scope.where(id: ConversationLink.where(link_type: "primary").select(:conversation_id))
    when "mention" then scope = scope.where(id: ConversationLink.where(link_type: "mention").select(:conversation_id))
    end

    if params[:q].present?
      term = "%#{params[:q].strip}%"
      scope = scope.where("title ILIKE :t OR thread_id ILIKE :t", t: term)
    end

    scope
  end

  def load_kpis
    @kpi_total = Conversation.count
    @kpi_by_source = Conversation.group(:source).count
    @kpi_ws_resolved = WorkspaceMap.where.not(folder: nil).count
    @kpi_ws_orphan = WorkspaceMap.orphan.count
    @kpi_no_title = Conversation.where(title: nil).count
    @kpi_last_sync = SyncRun.order(:created_at).last
    @kpi_skipped = SyncRun.sum(:skipped)
    @kpi_errors = SyncRun.sum(:error_lines)
  end
end
