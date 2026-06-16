class Contact < ApplicationRecord
  belongs_to :client

  validates :name, presence: true
  validates :email, presence: true
end
