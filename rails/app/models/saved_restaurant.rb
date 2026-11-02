class SavedRestaurant < ApplicationRecord
  belongs_to :user
  belongs_to :restaurant

  validates :restaurant_id, uniqueness: { scope: :user_id }
end
