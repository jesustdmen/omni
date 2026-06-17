class TimeEntry < ApplicationRecord
  belongs_to :task

  # `duration` é mantido como inteiro cru, em paridade com o RepoA (sem cronômetro
  # nem cálculo automático a partir de start/end nesta fase).
  validates :start_time, presence: true
  validates :date, presence: true
  validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :is_running, inclusion: { in: [ true, false ] }
  validate :end_time_not_before_start_time

  private

  def end_time_not_before_start_time
    return if end_time.blank? || start_time.blank?

    errors.add(:end_time, "deve ser igual ou posterior ao início") if end_time < start_time
  end
end
