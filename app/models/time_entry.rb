class TimeEntry < ApplicationRecord
  belongs_to :task

  # `duration` é persistido em SEGUNDOS e **derivado** (PB-003c): timer via stop!;
  # apontamento retroativo via início+término. Nunca é informado direto pelo form.
  before_validation :derive_date_and_duration

  validates :start_time, presence: true
  validates :date, presence: true
  validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :is_running, inclusion: { in: [ true, false ] }
  # PB-003c — apontamento NÃO running exige término; running NÃO pode ter término.
  validates :end_time, presence: true, unless: :is_running
  validate :end_time_not_before_start_time
  validate :running_has_no_end_time
  validate :running_has_zero_duration
  validate :running_timer_rules

  scope :running, -> { where(is_running: true) }

  # Config app-wide (ADR-014: sem regra por usuário no MVP).
  def self.allow_parallel_timers?
    Rails.configuration.x.allow_parallel_running_timers != false
  end

  # Inicia um timer para a tarefa (registro running). As validações aplicam as
  # regras de unicidade/paralelismo. Retorna o TimeEntry (persistido ou com erros).
  def self.start_for(task, at: Time.current)
    # `date` deriva do início no timezone da aplicação (Brasília), não em UTC.
    create(task: task, start_time: at, date: at.in_time_zone.to_date, is_running: true, duration: 0)
  end

  def running?
    is_running
  end

  # Para o timer: calcula duração em segundos e encerra. Seguro se já parado.
  def stop!(at: Time.current)
    return self unless is_running?

    update!(end_time: at, duration: [ (at - start_time).to_i, 0 ].max, is_running: false)
    self
  end

  private

  # PB-003c — centraliza derivações no model:
  #  - `date` SEMPRE deriva do início no timezone da aplicação (Brasília) — nunca em
  #    UTC, p/ não divergir do dia operacional perto da meia-noite (ADR-023);
  #  - `duration` só é derivada para apontamento NÃO running com início+término
  #    coerentes (running é gerido por start_for/stop!: fica 0 até parar);
  #  - NÃO computa duration quando término < início (deixa a validação acusar erro).
  def derive_date_and_duration
    self.date = start_time.in_time_zone.to_date if start_time.present?

    return if is_running
    return if start_time.blank? || end_time.blank?
    return if end_time < start_time

    self.duration = (end_time - start_time).to_i
  end

  def end_time_not_before_start_time
    return if end_time.blank? || start_time.blank?

    errors.add(:end_time, "deve ser igual ou posterior ao início") if end_time < start_time
  end

  def running_has_no_end_time
    errors.add(:end_time, "deve ficar vazio em timer em andamento") if is_running && end_time.present?
  end

  # PB-003c — timer em andamento não acumula duração até stop! (duração 0).
  def running_has_zero_duration
    errors.add(:duration, "deve ser 0 em timer em andamento") if is_running && duration.to_i != 0
  end

  # Regras de timer aberto (só quando este registro está running):
  #  - invariante dura: nunca 2 abertos na mesma tarefa (espelha o índice parcial);
  #  - paralelismo: se desabilitado, bloqueia se houver QUALQUER outro aberto.
  def running_timer_rules
    return unless is_running?

    if TimeEntry.running.where(task_id: task_id).where.not(id: id).exists?
      errors.add(:base, "Já existe um timer em andamento nesta tarefa.")
      return
    end

    return if self.class.allow_parallel_timers?

    if TimeEntry.running.where.not(id: id).exists?
      errors.add(:base, "Há um timer em andamento; pare-o antes (timers paralelos desabilitados).")
    end
  end
end
