class BrazeDelivery < ApplicationRecord
  STATUSES = %w[ pending recorded failed ].freeze

  belongs_to :user

  validates :idempotency_key, presence: true, uniqueness: true
  validates :endpoint, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
