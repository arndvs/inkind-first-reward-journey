# A payment at a restaurant. Named Txn to avoid clashing with ActiveRecord::Transactions.
class Txn < ApplicationRecord
  self.table_name = "transactions"

  belongs_to :user
  belongs_to :restaurant

  validates :transaction_key, presence: true, uniqueness: true
  validates :subtotal_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :tip_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :reward_is_usable, if: :reward_applied?

  private

  def reward_is_usable
    return if user.nil?

    reward = Reward.referral_welcome.unredeemed.find_by(user: user)
    if reward.nil?
      errors.add(:base, "This user has no unused referral reward")
      return
    end

    if reward.min_spend_cents.nil?
      errors.add(:base, "The referral reward has no minimum spend, so it can't be applied")
      return
    end

    return if subtotal_cents.to_i >= reward.min_spend_cents

    minimum = format("%.2f", reward.min_spend_cents / 100.0)
    errors.add(:base, "Subtotal must be at least $#{minimum} to use this reward")
  end
end
