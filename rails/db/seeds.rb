# Fictional data only. Mirrors sql/00_sample_data.sql so the Rails demo and the Snowflake
# proof of concept describe the same ten users. Idempotent: safe to run repeatedly.
#
# sql/00 has no session_start events: sessions are collected by the Braze SDK, not this app.
# Transactions have no restaurant, as in sql/00. App payments must name one (see Txn).

exported_at = Time.current
asset_base = ENV.fetch(
  "ASSET_BASE_URL",
  "https://raw.githubusercontent.com/arndvs/inkind-first-reward-journey/main/liquid/images/samples/"
)
# sql/00 timestamps are UTC
at = ->(text) { Time.zone.parse(text) }

restaurants = [
  { key: "r_101", name: "Lantern Row", location_id: "demo-101", cuisine: "Japanese · Small plates · Grill",
    price: "$$", rating: 4.6, cashback_pct: 20,
    description: "Charcoal-grilled skewers and small plates made for sharing.", image: "lantern-row" },
  { key: "r_201", name: "Nonna Pia's Kitchen", location_id: "demo-201", cuisine: "Italian, pasta",
    price: "$$$", cashback_pct: 15, image: "nonna-pias" },
  { key: "r_214", name: "Ember & Oak", location_id: "demo-202", cuisine: "Steakhouse, wood-fired grill",
    price: "$$$$", cashback_pct: 20, image: "ember-and-oak" },
  { key: "r_233", name: "Tidepool Taqueria", location_id: "demo-203", cuisine: "Mexican, tacos",
    price: "$$", cashback_pct: 10, image: "tidepool" },
  { key: "r_208", name: "Harbor Noodle House", location_id: "demo-208", cuisine: "Noodles",
    price: "$$", cashback_pct: 10, image: nil },
  { key: "r_219", name: "Saffron & Salt", location_id: "demo-219", cuisine: "Indian",
    price: "$$", cashback_pct: 15, image: nil }
]

restaurants.each do |attrs|
  Restaurant.find_or_create_by!(key: attrs[:key]) do |restaurant|
    restaurant.assign_attributes(attrs.except(:key, :image))
    if attrs[:image]
      restaurant.image_url = "#{asset_base}#{attrs[:image]}.jpg"
      restaurant.thumb_url = "#{asset_base}#{attrs[:image]}-thumb.jpg"
    end
  end
end

users = {
  "u_1001" => "2026-10-08 10:54:00",
  "u_1002" => "2026-09-20 18:30:00",
  "u_1003" => "2026-10-15 12:10:00",
  "u_1004" => "2026-10-01 09:00:00",
  "u_1005" => "2026-10-05 20:45:00",
  "u_1006" => "2026-10-18 17:20:00",
  "u_1007" => "2026-09-10 08:15:00",
  "u_1008" => "2026-10-20 13:05:00",
  "u_1009" => "2026-10-02 19:40:00",
  "u_1010" => "2026-10-09 11:25:00"
}

users.each do |external_id, created|
  User.find_or_create_by!(external_id: external_id) do |user|
    user.email = "user+#{external_id}@example.com"
    user.created_at = at.(created)
  end
end

# rw_02 starts unredeemed so that tx_01 can apply it; it is marked redeemed below.
rewards = [
  { key: "rw_01", user: "u_1001", amount: 2500, min: 5000, updated: "2026-10-08 10:54:00" },
  { key: "rw_02", user: "u_1002", amount: 2500, min: 5000, updated: "2026-10-03 19:41:00" },
  { key: "rw_03", user: "u_1003", amount: 1250, min: 5000, updated: "2026-10-15 12:10:00" },
  { key: "rw_04", user: "u_1004", amount: 2500, min: 5000, updated: "2026-10-01 09:00:00" },
  { key: "rw_06", user: "u_1006", amount: 2500, min: 5000, updated: "2026-10-18 17:20:00" },
  { key: "rw_07", user: "u_1007", amount: 2500, min: 5000, updated: "2026-09-10 08:15:00" },
  { key: "rw_08", user: "u_1008", amount: 2500, min: nil,  updated: "2026-10-20 13:05:00" },
  { key: "rw_09", user: "u_1009", amount: 2500, min: 5000, updated: "2026-10-02 19:40:00" },
  { key: "rw_10", user: "u_1010", amount: 2500, min: 5000, updated: "2026-10-09 11:25:00" }
]

rewards.each do |row|
  Reward.find_or_create_by!(reward_key: row[:key]) do |reward|
    reward.user = User.find_by!(external_id: row[:user])
    reward.reward_type = Reward::REFERRAL_WELCOME
    reward.amount_cents = row[:amount]
    reward.min_spend_cents = row[:min]
    reward.exported_at = exported_at
    reward.created_at = at.(row[:updated])
    reward.updated_at = at.(row[:updated])
  end
end

transactions = [
  { key: "tx_01", user: "u_1002", subtotal: 6420, applied: true,  at: "2026-10-03 19:41:00" },
  { key: "tx_02", user: "u_1002", subtotal: 4100, applied: false, at: "2026-10-17 20:12:00" },
  { key: "tx_03", user: "u_1004", subtotal: 3800, applied: false, at: "2026-10-12 18:55:00" },
  { key: "tx_04", user: "u_1009", subtotal: 7200, applied: false, at: "2026-10-14 19:20:00" }
]

transactions.each do |row|
  Txn.find_or_create_by!(transaction_key: row[:key]) do |txn|
    txn.user = User.find_by!(external_id: row[:user])
    txn.subtotal_cents = row[:subtotal]
    txn.reward_applied = row[:applied]
    txn.exported_at = exported_at
    txn.created_at = at.(row[:at])
  end
end

# tx_01 used rw_02, so the reward is redeemed after the payment exists.
rw_02 = Reward.find_by!(reward_key: "rw_02")
rw_02.update!(redeemed_at: at.("2026-10-03 19:41:00")) if rw_02.redeemed_at.nil?

saves = [
  { user: "u_1001", restaurant: "r_201", at: "2026-10-11 21:09:00" },
  { user: "u_1001", restaurant: "r_214", at: "2026-10-11 21:12:00" },
  { user: "u_1003", restaurant: "r_233", at: "2026-10-16 12:34:00" },
  { user: "u_1010", restaurant: "r_208", at: "2026-10-09 11:41:00" },
  { user: "u_1010", restaurant: "r_219", at: "2026-10-13 20:02:00" }
]

saves.each do |row|
  user = User.find_by!(external_id: row[:user])
  restaurant = Restaurant.find_by!(key: row[:restaurant])
  saved_at = at.(row[:at])

  SavedRestaurant.find_or_create_by!(user: user, restaurant: restaurant) do |saved|
    saved.created_at = saved_at
  end

  AppEvent.find_or_create_by!(user: user, event_name: "restaurant_saved", restaurant: restaurant, occurred_at: saved_at) do |event|
    event.exported_at = exported_at
  end
end
