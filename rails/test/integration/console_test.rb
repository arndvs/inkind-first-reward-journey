require "test_helper"

class ConsoleTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = create_user("u_1001")
    @lantern = create_restaurant("r_101")
    @reward = create_reward(@user, key: "rw_01", min_spend_cents: 5000, amount_cents: 2500)
  end

  test "the users index lists the users" do
    get root_path

    assert_response :success
    assert_includes response.body, "u_1001"
  end

  test "a user page shows the unused reward and its forms" do
    get user_path(@user)

    assert_response :success
    assert_includes response.body, "$25 unused"
    assert_includes response.body, "Record payment"
  end

  test "saving a restaurant produces one delivery with the save payload" do
    post user_saved_restaurants_path(@user), params: { saved_restaurant: { restaurant_id: @lantern.id } }
    assert_redirected_to user_path(@user)
    perform_enqueued_jobs

    delivery = BrazeDelivery.sole
    assert_equal "restaurant_saved:#{SavedRestaurant.sole.id}", delivery.idempotency_key
    assert_equal [ "r_101" ], delivery.payload["attributes"].first["saved_restaurants"]
    assert_equal "restaurant_saved", delivery.payload["events"].first["name"]
  end

  test "saving the same restaurant twice is refused and sends nothing new" do
    SavedRestaurant.create!(user: @user, restaurant: @lantern)

    post user_saved_restaurants_path(@user), params: { saved_restaurant: { restaurant_id: @lantern.id } }

    assert_response :unprocessable_content
    assert_includes response.body, "has already been taken"
    assert_equal 1, SavedRestaurant.count
  end

  test "a restaurant view produces one delivery with the view payload" do
    post user_restaurant_views_path(@user), params: { restaurant_view: { restaurant_id: @lantern.id } }
    assert_redirected_to user_path(@user)
    perform_enqueued_jobs

    delivery = BrazeDelivery.sole
    assert_equal "restaurant_viewed", delivery.payload["events"].first["name"]
    assert_equal "r_101", delivery.payload["events"].first["properties"]["restaurant_id"]
  end

  test "paying with the reward produces one purchase delivery with the right JSON" do
    post user_payments_path(@user),
         params: { payment: { restaurant_id: @lantern.id, subtotal: "62.40", tip: "12", use_reward: "1" } }
    assert_redirected_to user_path(@user)
    perform_enqueued_jobs

    delivery = BrazeDelivery.sole
    purchase = delivery.payload["purchases"].first
    assert_equal 62.4, purchase["price"]
    assert_equal "r_101", purchase["properties"]["restaurant_id"]
    assert_equal 12, purchase["properties"]["tip"]
    assert_equal true, purchase["properties"]["reward_applied"]
    assert_equal 25, purchase["properties"]["reward_amount"]
    assert_not_nil @reward.reload.redeemed_at
  end

  test "a subtotal below the reward minimum is refused and sends nothing" do
    post user_payments_path(@user),
         params: { payment: { restaurant_id: @lantern.id, subtotal: "38.00", tip: "0", use_reward: "1" } }

    assert_response :unprocessable_content
    assert_includes response.body, "at least $50.00"
    assert_equal 0, Txn.count
    perform_enqueued_jobs
    assert_equal 0, BrazeDelivery.count
  end

  test "an amount that is not a number is refused" do
    post user_payments_path(@user),
         params: { payment: { restaurant_id: @lantern.id, subtotal: "lots", tip: "0", use_reward: "0" } }

    assert_response :unprocessable_content
    assert_equal 0, Txn.count
  end

  test "the deliveries page lists each delivery" do
    post user_payments_path(@user),
         params: { payment: { restaurant_id: @lantern.id, subtotal: "62.40", tip: "0", use_reward: "0" } }
    perform_enqueued_jobs

    get deliveries_path

    assert_response :success
    assert_includes response.body, "purchase:"
  end
end
