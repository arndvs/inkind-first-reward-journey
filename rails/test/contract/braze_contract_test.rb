require "test_helper"

# The Braze payloads in 01-data-contract.md section 3 are the contract. These tests build the
# same payloads from records and compare them with the JSON in the doc, so the two can't drift.
class BrazeContractTest < ActiveSupport::TestCase
  CONTRACT_PATH = Rails.root.join("..", "01-data-contract.md")

  setup do
    @user = create_user("u_123")
    @mexican = Restaurant.create!(key: "r_456", name: "Test Taqueria", location_id: "demo-456", cuisine: "mexican")
    @other = Restaurant.create!(key: "r_789", name: "Test Noodles", location_id: "demo-789", cuisine: "noodles")
    @saved = SavedRestaurant.create!(user: @user, restaurant: @mexican, created_at: Time.utc(2026, 10, 24, 18, 2, 0))
    SavedRestaurant.create!(user: @user, restaurant: @other, created_at: Time.utc(2026, 10, 24, 18, 5, 0))

    Reward.create!(reward_key: "rw_contract", user: @user, reward_type: "referral_welcome",
                   amount_cents: 2500, min_spend_cents: 5000)
    @txn = Txn.create!(transaction_key: "tx_contract", user: @user, restaurant: @mexican,
                       subtotal_cents: 6240, tip_cents: 1200, reward_applied: true,
                       created_at: Time.utc(2026, 10, 25, 19, 41, 0))
  end

  def contract_samples
    # The Windows working copy may hold CRLF line endings; normalize before matching.
    text = File.read(CONTRACT_PATH).gsub("\r\n", "\n")
    section = text[/^## 3\..*?(?=^## 4\.)/m]
    flunk "section 3 not found in 01-data-contract.md" if section.nil?

    section.scan(/```json\n(.*?)```/m).flatten.map { |block| JSON.parse(block) }
  end

  test "section 3 holds exactly two JSON samples" do
    assert_equal 2, contract_samples.size
  end

  test "the restaurant_saved payload matches the sample in section 3" do
    sample = contract_samples.find { |payload| payload.key?("attributes") }

    payload = Braze::Payloads.restaurant_saved(@saved)

    assert_equal JSON.generate(sample), JSON.generate(payload)
    assert_nothing_raised { Braze::Validator.check!(sample) }
  end

  test "the purchase payload matches the sample in section 3" do
    sample = contract_samples.find { |payload| payload.key?("purchases") }

    payload = Braze::Payloads.purchase(@txn)

    assert_equal JSON.generate(sample), JSON.generate(payload)
    assert_nothing_raised { Braze::Validator.check!(sample) }
  end
end
