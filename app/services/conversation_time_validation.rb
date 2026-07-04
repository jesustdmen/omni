# PB-020e (Triagem) — visão de VALIDAÇÃO DE TEMPO de uma conversa, montada a partir
# dos blocos de trabalho (PB-020d). SOMENTE LEITURA: não grava nada, não cria
# TimeEntry/Task, não toca ConversationLink. O subtotal validado é a soma dos blocos
# `execution` + `confirmed`; gap confirmado é exibido à parte e NUNCA soma (não é
# cobrável); draft = pendente; discarded fica fora. Overlap entre execuções
# confirmadas (janelas com início/fim no mesmo dia) não é esperado — quando
# detectado, gera um AVISO simples (nada é somado/deduzido silenciosamente).
class ConversationTimeValidation
  DAY_PERIOD_ORDER = ConversationWorkBlock::DAY_PERIODS.each_with_index.to_h.freeze

  # Um turno (data + período) com seus blocos separados por papel na validação.
  Group = Struct.new(:period_date, :day_period, :executions_confirmed, :gaps_confirmed,
                     :pending, :subtotal_seconds, keyword_init: true) do
    def day_period_label = ConversationWorkBlock::DAY_PERIOD_LABELS.fetch(day_period, day_period)
  end

  Result = Struct.new(:groups, :total_validated_seconds, :confirmed_count, :reviewable_count,
                      :pending_count, :discarded_count, :overlap_warnings, keyword_init: true) do
    def empty? = groups.empty?
    def progress_label = "#{confirmed_count} de #{reviewable_count} confirmado(s)"
  end

  def self.call(conversation:)
    new(conversation: conversation).call
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    blocks = @conversation.work_blocks.includes(:client, :task).ordered.to_a
    reviewable = blocks.reject(&:discarded?)

    groups = build_groups(reviewable)
    Result.new(
      groups: groups,
      total_validated_seconds: groups.sum(&:subtotal_seconds),
      confirmed_count: reviewable.count(&:confirmed?),
      reviewable_count: reviewable.size,
      pending_count: reviewable.count(&:draft?),
      discarded_count: blocks.count(&:discarded?),
      overlap_warnings: detect_overlaps(reviewable)
    )
  end

  private

  # Agrupa por (data, turno) na ordem operacional (data asc; Manhã→Tarde→Noite).
  def build_groups(blocks)
    blocks
      .group_by { |b| [ b.period_date, b.day_period ] }
      .sort_by { |(date, period), _| [ date, DAY_PERIOD_ORDER.fetch(period, 99) ] }
      .map do |(date, period), do_turno|
        executions = do_turno.select { |b| b.execution? && b.confirmed? }
        Group.new(
          period_date: date,
          day_period: period,
          executions_confirmed: executions,
          gaps_confirmed: do_turno.select { |b| b.gap? && b.confirmed? },
          pending: do_turno.select(&:draft?),
          subtotal_seconds: executions.sum { |b| b.duration_seconds.to_i }
        )
      end
  end

  # Overlap simples entre EXECUÇÕES CONFIRMADAS com janela completa no mesmo dia.
  # Par sobreposto → mensagem técnica; a soma NÃO é ajustada (alerta explícito).
  def detect_overlaps(blocks)
    windows = blocks.select { |b| b.execution? && b.confirmed? && b.start_time.present? && b.end_time.present? }
    warnings = []
    windows.group_by(&:period_date).each_value do |do_dia|
      do_dia.sort_by(&:start_time).each_cons(2) do |a, b|
        next unless b.start_time < a.end_time

        warnings << "Janelas sobrepostas em #{a.period_date.strftime('%d/%m/%Y')} " \
                    "(#{a.day_period_label} × #{b.day_period_label}): o subtotal pode conter tempo duplicado."
      end
    end
    warnings
  end
end
