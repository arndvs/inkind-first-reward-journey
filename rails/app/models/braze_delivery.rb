class BrazeDelivery < ApplicationRecord
  STATUSES = %w[ pending recorded failed ].freeze

  belongs_to :user

  validates :idempotency_key, presence: true, uniqueness: true
  validates :endpoint, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def recorded?
    status == "recorded"
  end

  # The arguments Braze::TrackJob needs to send this delivery again: its kind, and the record it came from.
  # The key is "kind:identifier". A purchase's identifier is its transaction_key; the others use the record id.
  def job_arguments
    kind, identifier = idempotency_key.split(":", 2)
    record = case kind
    when "purchase" then Txn.find_by!(transaction_key: identifier)
    when "restaurant_saved" then SavedRestaurant.find(identifier)
    when "restaurant_viewed" then AppEvent.find(identifier)
    else raise ArgumentError, "unknown delivery kind: #{kind.inspect}"
    end
    [ kind, record.to_global_id.to_s ]
  end
end
