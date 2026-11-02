module Payments
  # Records a payment made in the app. The payment and the reward redemption commit together, or not at
  # all. Braze hears about the payment only after commit (Txn's after_create_commit). See
  # rails/ARCHITECTURE.md section 6.6.
  #
  # Order: check the reward, save the transaction (validations run), then redeem the reward.
  class Record
    def self.call(**attributes)
      new(**attributes).call
    end

    def self.redeem_reward!(reward, at)
      reward.update!(redeemed_at: at)
    end

    def initialize(user:, restaurant:, subtotal_cents:, tip_cents: 0, use_reward: false)
      @user = user
      @restaurant = restaurant
      @subtotal_cents = subtotal_cents
      @tip_cents = tip_cents
      @use_reward = use_reward
    end

    def call
      ActiveRecord::Base.transaction do
        reward = @use_reward ? @user.rewards.referral_welcome.unredeemed.first : nil

        txn = Txn.new(
          transaction_key: "tx_#{SecureRandom.hex(8)}",
          user: @user,
          restaurant: @restaurant,
          subtotal_cents: @subtotal_cents,
          tip_cents: @tip_cents,
          reward_applied: @use_reward,
          reward_amount_cents: reward&.amount_cents
        )
        txn.save!(context: :app_payment)

        self.class.redeem_reward!(reward, Time.current) if reward
        txn
      end
    end
  end
end
