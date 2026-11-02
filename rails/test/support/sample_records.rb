# Builders for fictional records used across the model tests.
# Every ID and email here is made up (user+<external_id>@example.com).
module SampleRecords
  def create_user(external_id = "u_1001")
    User.create!(external_id: external_id, email: "user+#{external_id}@example.com")
  end

  def create_restaurant(key = "r_101")
    Restaurant.create!(key: key, name: "Lantern Row", location_id: "demo-101")
  end

  def create_reward(user, key: "rw_01", min_spend_cents: 5000, amount_cents: 2500)
    Reward.create!(
      reward_key: key,
      user: user,
      reward_type: "referral_welcome",
      amount_cents: amount_cents,
      min_spend_cents: min_spend_cents
    )
  end
end
