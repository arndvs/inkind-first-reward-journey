class AddRewardAmountCentsToTransactions < ActiveRecord::Migration[8.1]
  # Set when a reward is applied to a payment, so the purchase payload reads the amount the
  # payment actually used, not the reward record's current amount.
  def change
    add_column :transactions, :reward_amount_cents, :integer
  end
end
