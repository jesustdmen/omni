class SyncRunItem < ApplicationRecord
  STATUSES = %w[error skipped].freeze

  belongs_to :sync_run

  validates :status, presence: true, inclusion: { in: STATUSES }
end
