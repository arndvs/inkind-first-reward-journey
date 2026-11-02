require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  def counts
    { users: User.count, rewards: Reward.count, transactions: Txn.count, restaurants: Restaurant.count }
  end

  test "seeding twice leaves the same counts" do
    Rails.application.load_seed
    first = counts

    Rails.application.load_seed

    assert_equal({ users: 10, rewards: 9, transactions: 4, restaurants: 4 }, first)
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
end
