require "test_helper"

class BrazeDeliveryTest < ActiveSupport::TestCase
  test "a second delivery with the same idempotency_key is refused" do
    user = create_user("u_1001")
    BrazeDelivery.create!(idempotency_key: "purchase:tx_01", user: user, endpoint: "/users/track", payload: {})

    duplicate = BrazeDelivery.new(idempotency_key: "purchase:tx_01", user: user, endpoint: "/users/track", payload: {})

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:idempotency_key].join, "already been taken"
  end
end
