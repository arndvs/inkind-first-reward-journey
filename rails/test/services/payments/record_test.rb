require "test_helper"
require "minitest/mock"

class PaymentsRecordTest < ActiveJob::TestCase
  setup do
    @user = create_user("u_1001")
    @lantern = create_restaurant("r_101")
    @reward = create_reward(@user, key: "rw_01", min_spend_cents: 5000, amount_cents: 2500)
  end

  test "a payment that uses the reward records the amount and redeems the reward" do
    txn = Payments::Record.call(user: @user, restaurant: @lantern, subtotal_cents: 6240, tip_cents: 1200, use_reward: true)

    assert txn.persisted?
    assert txn.reward_applied
    assert_equal 2500, txn.reward_amount_cents
    assert_not_nil @reward.reload.redeemed_at
  end

  test "a payment without the reward leaves it unused" do
    txn = Payments::Record.call(user: @user, restaurant: @lantern, subtotal_cents: 6240, tip_cents: 0, use_reward: false)

    assert_not txn.reward_applied
    assert_nil txn.reward_amount_cents
    assert_nil @reward.reload.redeemed_at
  end

  test "a subtotal below the reward minimum refuses the payment and changes nothing" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Payments::Record.call(user: @user, restaurant: @lantern, subtotal_cents: 3800, tip_cents: 0, use_reward: true)
    end

    assert_equal 0, Txn.count
    assert_nil @reward.reload.redeemed_at
  end

  test "a payment with no restaurant is refused" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Payments::Record.call(user: @user, restaurant: nil, subtotal_cents: 6240, tip_cents: 0, use_reward: false)
    end
  end

  test "using a reward the user does not have is refused" do
    other = create_user("u_1005")

    assert_raises(ActiveRecord::RecordInvalid) do
      Payments::Record.call(user: other, restaurant: @lantern, subtotal_cents: 6240, tip_cents: 0, use_reward: true)
    end
  end

  test "a failure after the payment is saved rolls everything back and sends nothing" do
    assert_no_enqueued_jobs do
      Payments::Record.stub(:redeem_reward!, ->(*) { raise "boom" }) do
        assert_raises(RuntimeError) do
          Payments::Record.call(user: @user, restaurant: @lantern, subtotal_cents: 6240, tip_cents: 0, use_reward: true)
        end
      end
    end

    assert_equal 0, Txn.count
    assert_nil @reward.reload.redeemed_at
    assert_equal 0, BrazeDelivery.count
  end

  test "one payment produces one purchase delivery with the reward amount" do
    Payments::Record.call(user: @user, restaurant: @lantern, subtotal_cents: 6240, tip_cents: 1200, use_reward: true)
    perform_enqueued_jobs

    delivery = BrazeDelivery.sole
    assert delivery.idempotency_key.start_with?("purchase:")
    assert_equal 25, delivery.payload["purchases"].first["properties"]["reward_amount"]
  end
end
