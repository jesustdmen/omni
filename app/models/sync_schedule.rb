# PB-016a — configuração (singleton) do agendamento interno da sincronização.
# Uma única linha; `current` cria-a na primeira leitura. O disparo agendado é
# feito pelo ScheduledSyncJob (recorrente, SolidQueue) — sem Tarefa do Windows.
class SyncSchedule < ApplicationRecord
  INTERVAL_OPTIONS = [ 15, 30, 60, 120, 240, 480, 1440 ].freeze # minutos (15min … 24h)
  MIN_INTERVAL = 5

  validates :interval_minutes, numericality: { only_integer: true, greater_than_or_equal_to: MIN_INTERVAL }

  # Singleton: sempre a mesma (única) linha de configuração.
  def self.current
    first || create!(enabled: false, interval_minutes: 60)
  end

  # Está na hora de disparar? (habilitado e passou o intervalo desde o último).
  def due?(now: Time.current)
    return false unless enabled

    last_enqueued_at.nil? || last_enqueued_at <= now - interval_minutes.minutes
  end

  def interval_label
    return "#{interval_minutes} min" if interval_minutes < 60
    return "#{interval_minutes / 60} h" if (interval_minutes % 60).zero?

    "#{interval_minutes} min"
  end
end
