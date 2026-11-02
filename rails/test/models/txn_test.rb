require "test_helper"

class TxnTest < ActiveSupport::TestCase
  setup do
    @user = create_user("u_1001")
    @restaurant = create_restaurant("r_101")
    @reward = create_reward(@user, key: "rw_01", min_spend_cents: 5000)
  end

  def build_txn(user: @user, subtotal_cents: 6240, reward_applied: true, key: "tx_test", restaurant: @restaurant)
    Txn.new(
      transaction_key: key,
      user: user,
      restaurant: restaurant,
      subtotal_cents: subtotal_cents,
      tip_cents: 0,
      reward_applied: reward_applied,
      reward_amount_cents: reward_applied ? 2500 : nil
    )
  end

  test "a payment with an unused reward at or above the minimum is valid" do
    assert build_txn(subtotal_cents: 6240).valid?
  end

  test "a payment without the reward is valid below the minimum" do
    assert build_txn(subtotal_cents: 3800, reward_applied: false).valid?
  end

  test "u_1004's $38 meal is refused under the $50 minimum" do
    user = create_user("u_1004")
    create_reward(user, key: "rw_04")

    txn = build_txn(user: user, subtotal_cents: 3800, key: "tx_u1004")

    assert_not txn.valid?
    assert_includes txn.errors[:base].join, "at least $50.00"
  end

  test "u_1008 is refused when the reward has no minimum spend" do
    user = create_user("u_1008")
    create_reward(user, key: "rw_08", min_spend_cents: nil)

    txn = build_txn(user: user, subtotal_cents: 6000, key: "tx_u1008")

    assert_not txn.valid?
    assert_includes txn.errors[:base].join, "no minimum spend"
  end

  test "a second use of a redeemed reward is refused" do
    @reward.update!(redeemed_at: Time.current)

    txn = build_txn(subtotal_cents: 6240, key: "tx_second")

    assert_not txn.valid?
    assert_includes txn.errors[:base].join, "no unused referral reward"
  end

  test "a payment must have a positive subtotal" do
    assert_not build_txn(subtotal_cents: 0, reward_applied: false).valid?
  end

  test "imported history can omit the restaurant" do
    assert build_txn(restaurant: nil, reward_applied: false).valid?
  end

  test "an app payment must name a restaurant" do
    txn = build_txn(restaurant: nil, reward_applied: false)

    assert_not txn.valid?(:app_payment)
    assert_predicate txn.errors[:restaurant], :any?
  end

  test "an app payment with a restaurant is valid" do
    assert build_txn(reward_applied: false).valid?(:app_payment)
  end

  test "a applied reward needs its amount recorded on the transaction" do
    txn = build_txn(subtotal_cents: 6240, reward_applied: true)
    txn.reward_amount_cents = nil

    assert_not txn.valid?
    assert_predicate txn.errors[:reward_amount_cents], :any?
  end
end
