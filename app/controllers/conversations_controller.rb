class ConversationsController < ApplicationController
  # F3.UI.1 — console SOMENTE LEITURA de validação da Fase 3.
  PER_PAGE = 50

  def index
    scope = filtered(policy_scope(Conversation))

    @total_count = scope.count
    @page = [ params[:page].to_i, 1 ].max
    @total_pages = [ (@total_count.to_f / PER_PAGE).ceil, 1 ].max
    @conversations = scope
      .order(Arel.sql("last_ts DESC NULLS LAST, updated_at DESC"))
      .limit(PER_PAGE)
      .offset((@page - 1) * PER_PAGE)

    load_kpis
    @sources = Conversation.distinct.pluck(:source).compact.sort
    @folders = WorkspaceMap.pluck(:workspace_hash, :folder).to_h
  end

  def show
    @conversation = Conversation.find(params[:id])
    authorize @conversation
    @folder = WorkspaceMap.find_by(workspace_hash: @conversation.workspace_hash)&.folder
  end

  private

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
