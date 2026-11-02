class AppEvent < ApplicationRecord
  belongs_to :user
  belongs_to :restaurant, optional: true

  validates :event_name, presence: true
  validates :occurred_at, presence: true
end
