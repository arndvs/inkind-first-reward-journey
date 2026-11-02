require "test_helper"

class CallbacksTest < ActiveJob::TestCase
  setup do
    @user = create_user("u_1001")
    @lantern = create_restaurant("r_101")
  end

  test "a save creates one restaurant_saved event and one track job" do
    assert_enqueued_jobs 1, only: Braze::TrackJob do
      SavedRestaurant.create!(user: @user, restaurant: @lantern)
    end

    assert_equal 1, AppEvent.where(event_name: "restaurant_saved").count
  end

  test "a restaurant_viewed event enqueues a track job" do
    assert_enqueued_jobs 1, only: Braze::TrackJob do
      AppEvent.create!(user: @user, event_name: "restaurant_viewed", restaurant: @lantern, occurred_at: Time.current)
    end
  end

  test "other app events enqueue nothing" do
    assert_no_enqueued_jobs do
      AppEvent.create!(user: @user, event_name: "session_start", occurred_at: Time.current)
    end
  end

  test "a payment enqueues a purchase track job" do
    assert_enqueued_jobs 1, only: Braze::TrackJob do
      Txn.create!(transaction_key: "tx_cb", user: @user, restaurant: @lantern,
                  subtotal_cents: 3800, tip_cents: 0, reward_applied: false)
    end
  end
end
