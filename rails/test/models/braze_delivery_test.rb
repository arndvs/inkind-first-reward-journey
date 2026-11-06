require "test_helper"

class BrazeDeliveryTest < ActiveSupport::TestCase
  test "job_arguments returns the kind and the record for a restaurant_saved delivery" do
    user = create_user("u_1001")
    restaurant = create_restaurant("r_101")
    saved = SavedRestaurant.create!(user: user, restaurant: restaurant)
    delivery = BrazeDelivery.create!(idempotency_key: "restaurant_saved:#{saved.id}", user: user,
                                     endpoint: "/users/track", payload: {})

    assert_equal [ "restaurant_saved", saved.to_global_id.to_s ], delivery.job_arguments
  end

  test "job_arguments rebuilds a restaurant_unsaved delivery from its event" do
    user = create_user("u_1001")
    restaurant = create_restaurant("r_101")
    event = AppEvent.create!(user: user, event_name: "restaurant_unsaved", restaurant: restaurant, occurred_at: Time.current)
    delivery = BrazeDelivery.create!(idempotency_key: "restaurant_unsaved:#{event.id}", user: user,
                                     endpoint: "/users/track", payload: {})

    assert_equal [ "restaurant_unsaved", event.to_global_id.to_s ], delivery.job_arguments
  end

  test "job_arguments finds a purchase by its transaction key" do
    user = create_user("u_1001")
    restaurant = create_restaurant("r_101")
    txn = Txn.create!(transaction_key: "tx_args", user: user, restaurant: restaurant,
                      subtotal_cents: 3800, tip_cents: 0, reward_applied: false)
    delivery = BrazeDelivery.create!(idempotency_key: "purchase:tx_args", user: user,
                                     endpoint: "/users/track", payload: {})

    assert_equal [ "purchase", txn.to_global_id.to_s ], delivery.job_arguments
  end

  test "job_arguments raises for a key it does not recognise" do
    user = create_user("u_1001")
    delivery = BrazeDelivery.create!(idempotency_key: "mystery:1", user: user, endpoint: "/users/track", payload: {})

    assert_raises(ArgumentError) { delivery.job_arguments }
  end

  test "a second delivery with the same idempotency_key is refused" do
    user = create_user("u_1001")
    BrazeDelivery.create!(idempotency_key: "purchase:tx_01", user: user, endpoint: "/users/track", payload: {})

    duplicate = BrazeDelivery.new(idempotency_key: "purchase:tx_01", user: user, endpoint: "/users/track", payload: {})

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:idempotency_key].join, "already been taken"
  end
end
