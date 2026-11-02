require "test_helper"

class BrazeValidatorTest < ActiveSupport::TestCase
  TIME = "2026-10-24T18:02:00Z".freeze

  def event(overrides = {})
    { "external_id" => "u_123", "name" => "restaurant_saved", "time" => TIME,
      "properties" => { "restaurant_id" => "r_456" } }.merge(overrides)
  end

  def purchase(overrides = {})
    { "external_id" => "u_123", "product_id" => "dine_in", "currency" => "USD", "price" => 62.4,
      "time" => TIME }.merge(overrides)
  end

  test "accepts a valid event payload" do
    assert_equal true, Braze::Validator.check!({ "events" => [ event ] })
  end

  test "accepts exactly 75 objects in one array" do
    payload = { "events" => Array.new(75) { event } }

    assert Braze::Validator.check!(payload)
  end

  test "rejects 76 events" do
    payload = { "events" => Array.new(76) { event } }

    error = assert_raises(Braze::InvalidPayload) { Braze::Validator.check!(payload) }
    assert_includes error.message, "76"
    assert_includes error.message, "75"
  end

  test "rejects a missing external_id" do
    error = assert_raises(Braze::InvalidPayload) do
      Braze::Validator.check!({ "events" => [ event("external_id" => nil) ] })
    end

    assert_includes error.message, "external_id"
  end

  test "rejects a bad time" do
    error = assert_raises(Braze::InvalidPayload) do
      Braze::Validator.check!({ "events" => [ event("time" => "tomorrow") ] })
    end

    assert_includes error.message, "time"
  end

  test "rejects a purchase without product_id" do
    error = assert_raises(Braze::InvalidPayload) do
      Braze::Validator.check!({ "purchases" => [ purchase("product_id" => nil) ] })
    end

    assert_includes error.message, "product_id"
  end
end
