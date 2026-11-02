require "test_helper"
require "minitest/mock"

class TrackJobTest < ActiveJob::TestCase
  # Stands in for Braze::Client. Records each payload, and raises the given error when set.
  class FakeClient
    attr_reader :payloads

    def initialize(error: nil)
      @error = error
      @payloads = []
    end

    def track(payload)
      @payloads << payload
      raise @error if @error

      { "message" => "recorded" }
    end
  end

  setup do
    @user = create_user("u_1001")
    @restaurant = create_restaurant("r_101")
    @saved = SavedRestaurant.create!(user: @user, restaurant: @restaurant)
    @gid = @saved.to_global_id.to_s
  end

  test "running the job twice leaves one delivery and makes one client call" do
    client = FakeClient.new

    Braze::Client.stub(:new, client) do
      2.times { Braze::TrackJob.perform_now("restaurant_saved", @gid) }
    end

    assert_equal 1, BrazeDelivery.count
    assert_equal 1, client.payloads.size
    assert_equal "recorded", BrazeDelivery.sole.status
    assert_equal "restaurant_saved:#{@saved.id}", BrazeDelivery.sole.idempotency_key
  end

  test "a retryable error keeps the delivery pending, records the error and schedules a retry" do
    client = FakeClient.new(error: Braze::RetryableError.new("Braze returned 503"))

    Braze::Client.stub(:new, client) do
      assert_enqueued_with(job: Braze::TrackJob) { Braze::TrackJob.perform_now("restaurant_saved", @gid) }
    end

    delivery = BrazeDelivery.sole
    assert_equal "pending", delivery.status
    assert_equal 1, delivery.attempts
    assert_includes delivery.last_error, "503"
  end

  test "a permanent error marks the delivery failed and is not retried" do
    client = FakeClient.new(error: Braze::PermanentError.new("Braze returned 400"))

    assert_no_enqueued_jobs do
      Braze::Client.stub(:new, client) { Braze::TrackJob.perform_now("restaurant_saved", @gid) }
    end

    delivery = BrazeDelivery.sole
    assert_equal "failed", delivery.status
    assert_includes delivery.last_error, "400"
  end

  test "the stored payload does not change when its source record is edited" do
    txn = Txn.create!(transaction_key: "tx_edit", user: @user, restaurant: @restaurant,
                      subtotal_cents: 3800, tip_cents: 0, reward_applied: false)
    gid = txn.to_global_id.to_s

    first = FakeClient.new(error: Braze::RetryableError.new("Braze returned 503"))
    Braze::Client.stub(:new, first) { Braze::TrackJob.perform_now("purchase", gid) }

    txn.update!(subtotal_cents: 9999)

    second = FakeClient.new
    Braze::Client.stub(:new, second) { Braze::TrackJob.perform_now("purchase", gid) }

    assert_equal first.payloads.first, second.payloads.first
    assert_equal 38, second.payloads.first["purchases"].first["price"]
  end
end
