class SyncRun < ApplicationRecord
  STATUSES = %w[ok partial error].freeze

  has_many :items, class_name: "SyncRunItem", dependent: :destroy
  # PB-015 — execução-mãe opcional (nil para runs antigos / disparados por rake).
  belongs_to :sync_execution, optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
end
