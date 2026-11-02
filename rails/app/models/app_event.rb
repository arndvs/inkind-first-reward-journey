class AppEvent < ApplicationRecord
  belongs_to :user
  belongs_to :restaurant, optional: true

  validates :event_name, presence: true
  validates :occurred_at, presence: true

  after_create_commit :track_view, if: -> { event_name == "restaurant_viewed" }

  private

  def track_view
    Braze::TrackJob.perform_later("restaurant_viewed", to_global_id.to_s)
  end
end
