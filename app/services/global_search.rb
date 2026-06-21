# PB-013 — busca global sobre os dados funcionais do Omni. Resultados agrupados
# por categoria; cada item carrega `matched_in` (campos/origem onde casou) para a
# UI exibir "Encontrado em: …". NÃO pesquisa conteúdo de turnos de conversa (ADR-021).
class GlobalSearch
  PER_CATEGORY = 5 # top-N por categoria (com "ver todos" quando há mais)

  # Um grupo de resultados de uma categoria.
  Group = Struct.new(:key, :label, :hits, :total, :see_all_path, keyword_init: true) do
    def more? = total > hits.size
  end
  # Um resultado individual (genérico p/ a view).
  Hit = Struct.new(:record, :matched_in, keyword_init: true)

  def self.call(query:, user:)
    new(query: query, user: user).call
  end

  def initialize(query:, user:)
    @q = query.to_s.strip
    @user = user
  end

  def call
    return [] if @q.blank?

    [ tasks_group, demands_group, projects_group, clients_group, contacts_group, conversations_group ]
      .reject { |g| g.hits.empty? }
  end

  # total de hits (todas as categorias) — p/ a UI saber se houve algo.
  def self.any?(groups)
    groups.any? { |g| g.hits.any? }
  end

  private

  # Escapa curingas do LIKE (% e _) e o escape (\) → termo tratado como texto.
  def like
    "%#{@q.gsub('\\', '\\\\\\\\').gsub('%', '\\%').gsub('_', '\\_')}%"
  end

  def cnpj_digits
    Client.normalize_cnpj_digits(@q)
  end

  # --- Tarefas: título/descrição + checklist + apontamento (DISTINCT) -------
  def tasks_group
    base = Task.where(
      "tasks.title ILIKE :p OR tasks.description ILIKE :p OR " \
      "tasks.id IN (SELECT task_id FROM checklist_items WHERE content ILIKE :p) OR " \
      "tasks.id IN (SELECT task_id FROM time_entries WHERE description ILIKE :p)",
      p: like
    ).distinct

    total = base.count
    records = base.includes(:client).order(created_at: :desc).limit(PER_CATEGORY).to_a
    hits = records.map { |t| Hit.new(record: t, matched_in: task_matched_in(t)) }
    Group.new(key: "tasks", label: "Tarefas", hits: hits, total: total,
              see_all_path: Rails.application.routes.url_helpers.tasks_path(q: @q))
  end

  # Recalcula em quais campos casou (consultas escopadas à tarefa; conjunto pequeno).
  def task_matched_in(task)
    fields = []
    fields << "Título" if ilike?(task.title)
    fields << "Descrição" if ilike?(task.description)
    fields << "Checklist" if task.checklist_items.where("content ILIKE :p", p: like).exists?
    fields << "Apontamento" if task.time_entries.where("description ILIKE :p", p: like).exists?
    fields
  end

  # --- Demandas -------------------------------------------------------------
  def demands_group
    base = Demand.where("title ILIKE :p OR description ILIKE :p OR observations ILIKE :p", p: like)
    total = base.count
    records = base.includes(:client).order(created_at: :desc).limit(PER_CATEGORY).to_a
    hits = records.map do |d|
      fields = []
      fields << "Título" if ilike?(d.title)
      fields << "Descrição" if ilike?(d.description)
      fields << "Observações" if ilike?(d.observations)
      Hit.new(record: d, matched_in: fields)
    end
    Group.new(key: "demands", label: "Demandas", hits: hits, total: total,
              see_all_path: Rails.application.routes.url_helpers.demands_path(q: @q))
  end

  # --- Projetos -------------------------------------------------------------
  def projects_group
    base = Project.where("name ILIKE :p OR description ILIKE :p", p: like)
    total = base.count
    records = base.includes(:client).order(:name).limit(PER_CATEGORY).to_a
    hits = records.map do |pr|
      fields = []
      fields << "Nome" if ilike?(pr.name)
      fields << "Descrição" if ilike?(pr.description)
      Hit.new(record: pr, matched_in: fields)
    end
    Group.new(key: "projects", label: "Projetos", hits: hits, total: total,
              see_all_path: Rails.application.routes.url_helpers.projects_path(q: @q))
  end

  # --- Clientes (nome/fantasia/CNPJ com-ou-sem pontuação) -------------------
  def clients_group
    sql = "name ILIKE :p OR trade_name ILIKE :p"
    args = { p: like }
    if cnpj_digits.present?
      sql += " OR cnpj LIKE :c"
      args[:c] = "%#{cnpj_digits}%"
    end
    base = Client.where(sql, **args)
    total = base.count
    records = base.order(:name).limit(PER_CATEGORY).to_a
    hits = records.map do |c|
      fields = []
      fields << "Nome" if ilike?(c.name)
      fields << "Nome fantasia" if ilike?(c.trade_name)
      fields << "CNPJ" if cnpj_digits.present? && c.cnpj.to_s.include?(cnpj_digits)
      Hit.new(record: c, matched_in: fields)
    end
    Group.new(key: "clients", label: "Clientes", hits: hits, total: total,
              see_all_path: Rails.application.routes.url_helpers.clients_path(q: @q))
  end

  # --- Contatos (nome/email/telefone/cargo) ---------------------------------
  def contacts_group
    base = Contact.where("name ILIKE :p OR email ILIKE :p OR phone ILIKE :p OR position ILIKE :p", p: like)
    total = base.count
    records = base.includes(:client).order(:name).limit(PER_CATEGORY).to_a
    hits = records.map do |c|
      fields = []
      fields << "Nome" if ilike?(c.name)
      fields << "E-mail" if ilike?(c.email)
      fields << "Telefone" if ilike?(c.phone)
      fields << "Cargo" if ilike?(c.position)
      Hit.new(record: c, matched_in: fields)
    end
    Group.new(key: "contacts", label: "Contatos", hits: hits, total: total,
              see_all_path: Rails.application.routes.url_helpers.clients_path(tab: "contacts", q: @q))
  end

  # --- Conversas (só título; sem conteúdo de turnos — ADR-021) --------------
  def conversations_group
    base = Conversation.where("title ILIKE :p", p: like)
    total = base.count
    records = base.order(Arel.sql("last_ts DESC NULLS LAST")).limit(PER_CATEGORY).to_a
    hits = records.map { |c| Hit.new(record: c, matched_in: [ "Título" ]) }
    Group.new(key: "conversations", label: "Conversas", hits: hits, total: total,
              see_all_path: Rails.application.routes.url_helpers.conversations_path(q: @q))
  end

  def ilike?(value)
    value.to_s.downcase.include?(@q.downcase)
  end
end
