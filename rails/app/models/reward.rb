class Reward < ApplicationRecord
  REFERRAL_WELCOME = "referral_welcome".freeze

  belongs_to :user

  scope :referral_welcome, -> { where(reward_type: REFERRAL_WELCOME) }
  scope :unredeemed, -> { where(redeemed_at: nil) }

  validates :reward_key, presence: true, uniqueness: true
  validates :reward_type, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :min_spend_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
