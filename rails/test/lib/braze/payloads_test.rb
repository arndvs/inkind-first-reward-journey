require "test_helper"

class BrazePayloadsTest < ActiveSupport::TestCase
  setup do
    @user = create_user("u_1001")
    @lantern = Restaurant.create!(key: "r_101", name: "Lantern Row", location_id: "demo-101", cuisine: "Japanese")
    Reward.create!(reward_key: "rw_01", user: @user, reward_type: "referral_welcome",
                   amount_cents: 2500, min_spend_cents: 5000)
  end

  test "purchase is a JSON number for price and omits restaurant_id when there is none" do
    txn = Txn.create!(transaction_key: "tx_nr", user: @user, subtotal_cents: 3800, tip_cents: 0,
                      reward_applied: false, created_at: Time.utc(2026, 10, 12, 18, 55))

    purchase = JSON.parse(Braze::Payloads.purchase(txn).to_json)["purchases"].first

    assert_kind_of Integer, purchase["price"]
    assert_equal 38, purchase["price"]
    assert_not purchase["properties"].key?("restaurant_id")
    assert_not purchase["properties"].key?("reward_amount")
  end

  test "purchase includes restaurant_id and reward_amount when a reward is applied" do
    txn = Txn.create!(transaction_key: "tx_r", user: @user, restaurant: @lantern, subtotal_cents: 6240,
                      tip_cents: 1200, reward_applied: true, reward_amount_cents: 2500, created_at: Time.utc(2026, 10, 25, 19, 41))

    properties = Braze::Payloads.purchase(txn)["purchases"].first["properties"]

    assert_equal "r_101", properties["restaurant_id"]
    assert_equal 62.4, properties["subtotal"]
    assert_equal 12.0, properties["tip"]
    assert_equal 25.0, properties["reward_amount"]
  end

  test "payloads never contain an email or other personal field" do
    txn = Txn.create!(transaction_key: "tx_pii", user: @user, restaurant: @lantern, subtotal_cents: 6240,
                      tip_cents: 0, reward_applied: true, reward_amount_cents: 2500, created_at: Time.utc(2026, 10, 25, 19, 41))

    assert_not_includes Braze::Payloads.purchase(txn).to_json, "@example.com"
    assert_not_includes Braze::Payloads.purchase(txn).to_json, "email"
  end

  test "saved_restaurants lists the user's restaurant keys in save order" do
    other = Restaurant.create!(key: "r_214", name: "Ember & Oak", location_id: "demo-202", cuisine: "Steakhouse")
    SavedRestaurant.create!(user: @user, restaurant: other, created_at: Time.utc(2026, 10, 11, 21, 12))
    saved = SavedRestaurant.create!(user: @user, restaurant: @lantern, created_at: Time.utc(2026, 10, 11, 21, 9))

    attributes = Braze::Payloads.restaurant_saved(saved)["attributes"].first

    assert_equal %w[ r_101 r_214 ], attributes["saved_restaurants"]
  end

  test "times are ISO 8601 UTC with a Z suffix and no fractional seconds" do
    saved = SavedRestaurant.create!(user: @user, restaurant: @lantern, created_at: Time.utc(2026, 10, 24, 18, 2, 0.5))

    time = Braze::Payloads.restaurant_saved(saved)["events"].first["time"]

    assert_equal "2026-10-24T18:02:00Z", time
  end

  test "the purchase reward amount comes from the transaction, not the reward record" do
    txn = Txn.create!(transaction_key: "tx_snap", user: @user, restaurant: @lantern, subtotal_cents: 6240,
                      tip_cents: 0, reward_applied: true, reward_amount_cents: 2500,
                      created_at: Time.utc(2026, 10, 25, 19, 41))
    Reward.find_by!(reward_key: "rw_01").update!(amount_cents: 1000)

    properties = Braze::Payloads.purchase(txn)["purchases"].first["properties"]

    assert_equal 25, properties["reward_amount"]
  end

  test "restaurant_unsaved carries the remaining keys and the removed restaurant" do
    other = Restaurant.create!(key: "r_214", name: "Ember & Oak", location_id: "demo-202", cuisine: "Steakhouse")
    SavedRestaurant.create!(user: @user, restaurant: other)
    saved = SavedRestaurant.create!(user: @user, restaurant: @lantern)
    saved.destroy!
    event = AppEvent.find_by!(event_name: "restaurant_unsaved")

    payload = Braze::Payloads.restaurant_unsaved(event)

    assert_equal %w[ r_214 ], payload["attributes"].first["saved_restaurants"]
    assert_equal "restaurant_unsaved", payload["events"].first["name"]
    assert_equal "r_101", payload["events"].first["properties"]["restaurant_id"]
    assert_nothing_raised { Braze::Validator.check!(payload) }
  end
end
