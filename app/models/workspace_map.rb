class WorkspaceMap < ApplicationRecord
  validates :workspace_hash, presence: true, uniqueness: true

  # Órfão = workspace visto em conversas, mas sem mapeamento conhecido (folder IS NULL).
  scope :orphan, -> { where(folder: nil) }
end
