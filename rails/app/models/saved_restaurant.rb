class SavedRestaurant < ApplicationRecord
  belongs_to :user
  belongs_to :restaurant

  validates :restaurant_id, uniqueness: { scope: :user_id }

  # The event is written inside the save's transaction, so a save never exists without its event.
  after_create :write_saved_event
  # Braze hears about the save only after commit, so a rolled-back save is never sent.
  after_create_commit { Braze::TrackJob.perform_later("restaurant_saved", to_global_id.to_s) }
  # Removal writes an event rather than deleting history. The row is gone after destroy, so the event is
  # what a track job can locate.
  after_destroy :write_unsaved_event, unless: :destroyed_by_association

  private

  def write_unsaved_event
    AppEvent.create!(user: user, event_name: "restaurant_unsaved", restaurant: restaurant, occurred_at: Time.current)
  end

  def write_saved_event
    AppEvent.create!(user: user, event_name: "restaurant_saved", restaurant: restaurant, occurred_at: created_at)
  end
end
