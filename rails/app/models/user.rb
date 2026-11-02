class User < ApplicationRecord
  has_many :rewards, dependent: :destroy
  has_many :saved_restaurants, dependent: :destroy
  has_many :restaurants, through: :saved_restaurants
  has_many :transactions, class_name: "Txn", dependent: :destroy
  has_many :app_events, dependent: :destroy
  has_many :braze_deliveries, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :external_id, presence: true, uniqueness: true
  validates :email, presence: true
end
