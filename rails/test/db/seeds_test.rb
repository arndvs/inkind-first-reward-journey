require "test_helper"

class SeedsTest < ActiveJob::TestCase
  def counts
    {
      users: User.count,
      rewards: Reward.count,
      transactions: Txn.count,
      restaurants: Restaurant.count,
      saved_restaurants: SavedRestaurant.count,
      restaurant_saved_events: AppEvent.where(event_name: "restaurant_saved").count
    }
  end

  test "seeding twice leaves the same counts" do
    Rails.application.load_seed
    first = counts

    Rails.application.load_seed

    assert_equal(
      { users: 10, rewards: 9, transactions: 4, restaurants: 6, saved_restaurants: 5, restaurant_saved_events: 5 },
      first
    )
    assert_equal first, counts
  end

  test "seeded rewards match sql/00: u_1008 has no minimum, rw_02 is already redeemed" do
    Rails.application.load_seed

    assert_nil Reward.find_by!(reward_key: "rw_08").min_spend_cents
    assert_not_nil Reward.find_by!(reward_key: "rw_02").redeemed_at
    assert_nil Reward.find_by!(reward_key: "rw_01").redeemed_at
  end

  test "everything seeded is marked exported so the exporter only sends new activity" do
    Rails.application.load_seed

    assert_empty Reward.where(exported_at: nil)
    assert_empty Txn.where(exported_at: nil)
    assert_empty AppEvent.where(exported_at: nil)
  end

  test "u_1010 saved r_208 and r_219, which have no photo" do
    Rails.application.load_seed

    user = User.find_by!(external_id: "u_1010")
    assert_equal %w[ r_208 r_219 ], user.restaurants.pluck(:key).sort
    assert_nil Restaurant.find_by!(key: "r_208").image_url
    assert_nil Restaurant.find_by!(key: "r_219").thumb_url
  end

  test "seeded transactions have no restaurant, matching sql/00" do
    Rails.application.load_seed

    assert_equal 4, Txn.where(restaurant_id: nil).count
  end

  test "tx_01 records the reward amount it used" do
    Rails.application.load_seed

    assert_equal 2500, Txn.find_by!(transaction_key: "tx_01").reward_amount_cents
  end

  test "seeding enqueues no jobs" do
    assert_no_enqueued_jobs { Rails.application.load_seed }
  end
end
