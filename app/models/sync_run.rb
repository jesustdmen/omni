class SyncRun < ApplicationRecord
  STATUSES = %w[ok partial error].freeze

  has_many :items, class_name: "SyncRunItem", dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }
end
