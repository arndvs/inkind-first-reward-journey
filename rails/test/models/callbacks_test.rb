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

  test "a save and its restaurant_saved event are written together or not at all" do
    AppEvent.stub(:create!, ->(*) { raise "event write failed" }) do
      assert_no_enqueued_jobs do
        assert_raises(RuntimeError) { SavedRestaurant.create!(user: @user, restaurant: @lantern) }
      end
    end

    assert_equal 0, SavedRestaurant.count
    assert_equal 0, AppEvent.count
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

  test "removing a saved restaurant writes one restaurant_unsaved event and one track job" do
    saved = SavedRestaurant.create!(user: @user, restaurant: @lantern)

    assert_enqueued_jobs 1, only: Braze::TrackJob do
      saved.destroy!
    end

    assert_nil SavedRestaurant.find_by(id: saved.id)
    event = AppEvent.find_by!(event_name: "restaurant_unsaved")
    assert_equal @user, event.user
    assert_equal @lantern, event.restaurant
  end

  test "a removal and its restaurant_unsaved event are written together or not at all" do
    saved = SavedRestaurant.create!(user: @user, restaurant: @lantern)

    AppEvent.stub(:create!, ->(*) { raise "event write failed" }) do
      assert_no_enqueued_jobs do
        assert_raises(RuntimeError) { saved.destroy! }
      end
    end

    assert SavedRestaurant.exists?(saved.id)
  end

  test "deleting a user does not write restaurant_unsaved events or track jobs" do
    SavedRestaurant.create!(user: @user, restaurant: @lantern)

    assert_no_enqueued_jobs only: Braze::TrackJob do
      @user.destroy!
    end

    assert_equal 0, AppEvent.where(event_name: "restaurant_unsaved").count
  end
end
