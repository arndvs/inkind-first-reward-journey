class Restaurant < ApplicationRecord
  has_many :saved_restaurants, dependent: :destroy
  has_many :transactions, class_name: "Txn", dependent: :restrict_with_error
  has_many :app_events, dependent: :nullify

  validates :key, presence: true, uniqueness: true
  validates :name, :location_id, presence: true
end
