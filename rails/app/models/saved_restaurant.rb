class SavedRestaurant < ApplicationRecord
  belongs_to :user
  belongs_to :restaurant

  validates :restaurant_id, uniqueness: { scope: :user_id }

  after_create_commit :record_save

  private

  # Writes the restaurant_saved event the funnel reads, then sends the save to Braze.
  def record_save
    AppEvent.create!(user: user, event_name: "restaurant_saved", restaurant: restaurant, occurred_at: created_at)
    Braze::TrackJob.perform_later("restaurant_saved", to_global_id.to_s)
  end
end
