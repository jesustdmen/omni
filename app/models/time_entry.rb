class TimeEntry < ApplicationRecord
  belongs_to :task

  # `duration` é persistido em SEGUNDOS (PB-003a). Timer parado calcula a duração
  # a partir de start_time/end_time; apontamento manual informa o valor direto.
  validates :start_time, presence: true
  validates :date, presence: true
  validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :is_running, inclusion: { in: [ true, false ] }
  validate :end_time_not_before_start_time
  validate :running_timer_rules

  scope :running, -> { where(is_running: true) }

  # Config app-wide (ADR-014: sem regra por usuário no MVP).
  def self.allow_parallel_timers?
    Rails.configuration.x.allow_parallel_running_timers != false
  end

  # Inicia um timer para a tarefa (registro running). As validações aplicam as
  # regras de unicidade/paralelismo. Retorna o TimeEntry (persistido ou com erros).
  def self.start_for(task, at: Time.current)
    create(task: task, start_time: at, date: at.to_date, is_running: true, duration: 0)
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

  def end_time_not_before_start_time
    return if end_time.blank? || start_time.blank?

    errors.add(:end_time, "deve ser igual ou posterior ao início") if end_time < start_time
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
