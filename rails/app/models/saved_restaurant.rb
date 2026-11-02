class SavedRestaurant < ApplicationRecord
  belongs_to :user
  belongs_to :restaurant

  validates :restaurant_id, uniqueness: { scope: :user_id }

  # The event is written inside the save's transaction, so a save never exists without its event.
  after_create :write_saved_event
  # Braze hears about the save only after commit, so a rolled-back save is never sent.
  after_create_commit { Braze::TrackJob.perform_later("restaurant_saved", to_global_id.to_s) }

  private

  def write_saved_event
    AppEvent.create!(user: user, event_name: "restaurant_saved", restaurant: restaurant, occurred_at: created_at)
  end
end
