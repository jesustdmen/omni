class Demand < ApplicationRecord
  # Listas fechadas confirmadas no validator do RepoA (server/src/validators/demands.ts).
  ORIGINS = %w[phone email meeting chat whatsapp other].freeze
  PRIORITIES = %w[low medium high].freeze

  belongs_to :client, optional: true

  enum :status, { pending: "pending", converted: "converted" }, default: "pending", validate: true

  validates :title, presence: true
  validates :origin, presence: true, inclusion: { in: ORIGINS }
  validates :priority, presence: true, inclusion: { in: PRIORITIES }
  validates :status, presence: true
end
