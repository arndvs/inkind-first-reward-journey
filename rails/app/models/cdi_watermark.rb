class CdiWatermark < ApplicationRecord
  validates :view_name, presence: true, uniqueness: true
end
