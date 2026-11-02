class AppEvent < ApplicationRecord
  belongs_to :user
  belongs_to :restaurant, optional: true

  validates :event_name, presence: true
  validates :occurred_at, presence: true

  before_validation :assign_event_key, on: :create
  after_create_commit :track_view, if: -> { event_name == "restaurant_viewed" }

  # The same inputs always give the same key. Snowflake MERGEs on it (rails/ARCHITECTURE.md section 6.8).
  def self.event_key_for(event_name:, user_external_id:, restaurant_key:, occurred_at:)
    [ event_name, user_external_id, restaurant_key.presence || "-", occurred_at.utc.iso8601(6) ].join(":")
  end

  private

  def assign_event_key
    return if user.nil? || occurred_at.nil?

    self.event_key ||= self.class.event_key_for(
      event_name: event_name,
      user_external_id: user.external_id,
      restaurant_key: restaurant&.key,
      occurred_at: occurred_at
    )
  end

  def track_view
    Braze::TrackJob.perform_later("restaurant_viewed", to_global_id.to_s)
  end
end
