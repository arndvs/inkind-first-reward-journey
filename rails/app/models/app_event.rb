class AppEvent < ApplicationRecord
  belongs_to :user
  belongs_to :restaurant, optional: true

  validates :event_name, presence: true
  validates :occurred_at, presence: true

  # Events Braze hears about. Each one is sent as its own /users/track body.
  TRACKED_EVENTS = %w[ restaurant_viewed restaurant_unsaved ].freeze

  before_validation :assign_event_key, on: :create
  after_create_commit :track, if: -> { TRACKED_EVENTS.include?(event_name) }

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

  def track
    Braze::TrackJob.perform_later(event_name, to_global_id.to_s)
  end
end
