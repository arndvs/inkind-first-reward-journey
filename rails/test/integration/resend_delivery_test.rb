require "test_helper"

class ResendDeliveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # Stands in for Braze::Client and counts how many payloads reach it.
  class CallCounter
    attr_reader :count

    def initialize
      @count = 0
    end

    def track(_payload)
      @count += 1
      { "message" => "recorded" }
    end
  end

  setup do
    @user = create_user("u_1001")
    @lantern = create_restaurant("r_101")
    @saved = SavedRestaurant.create!(user: @user, restaurant: @lantern)
    # The save only enqueues its job. Run it once so the delivery exists, then start each test from an empty queue.
    perform_enqueued_jobs
    clear_enqueued_jobs
    @delivery = BrazeDelivery.find_by!(idempotency_key: "restaurant_saved:#{@saved.id}")
  end

  test "the deliveries page has a Re-send button for each delivery" do
    get deliveries_path

    assert_response :success
    assert_includes response.body, resend_delivery_path(@delivery)
    assert_includes response.body, "Re-send"
  end

  test "clicking Re-send twice, with the jobs run in between, leaves one delivery" do
    2.times do
      post resend_delivery_path(@delivery)
      assert_redirected_to deliveries_path
      perform_enqueued_jobs
    end

    assert_equal 1, BrazeDelivery.count
    assert_equal "recorded", @delivery.reload.status
  end

  test "clicking Re-send twice before the jobs run still leaves one delivery" do
    2.times { post resend_delivery_path(@delivery) }
    assert_equal 2, enqueued_jobs.size

    perform_enqueued_jobs

    assert_equal 1, BrazeDelivery.count
  end

  test "re-sending a recorded delivery makes no Braze call" do
    # Setup already recorded this delivery, so both re-sends should find it recorded and stop.
    assert_equal "recorded", @delivery.reload.status
    calls = CallCounter.new

    Braze::Client.stub(:new, calls) do
      post resend_delivery_path(@delivery)
      perform_enqueued_jobs
      post resend_delivery_path(@delivery)
      perform_enqueued_jobs
    end

    assert_equal 0, calls.count
  end

  test "re-sending a purchase finds the transaction by its key" do
    txn = Txn.create!(transaction_key: "tx_resend", user: @user, restaurant: @lantern,
                      subtotal_cents: 3800, tip_cents: 0, reward_applied: false)
    purchase = BrazeDelivery.create!(
      idempotency_key: "purchase:tx_resend", user: @user, endpoint: "/users/track",
      payload: Braze::Payloads.purchase(txn), status: "failed"
    )

    post resend_delivery_path(purchase)
    perform_enqueued_jobs

    assert_equal "recorded", purchase.reload.status
    assert_equal 2, BrazeDelivery.count
  end

  test "a delivery whose record was deleted says so and enqueues nothing" do
    @saved.destroy!

    assert_no_enqueued_jobs do
      post resend_delivery_path(@delivery)
    end

    assert_redirected_to deliveries_path
    assert_equal "The record for this delivery could not be found, so nothing was re-sent.", flash[:alert]
  end
end
