require "test_helper"

class DemoResetTest < ActiveSupport::TestCase
  setup do
    user = create_user("u_1001")
    reward = create_reward(user, key: "rw_01", min_spend_cents: 5000, amount_cents: 2500)
    reward.update!(exported_at: Time.current)
    CdiWatermark.create!(view_name: Warehouse::CdiPreview::VIEW, synced_through: Time.current)
  end

  def in_development(&block)
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development"), &block)
  end

  def stub_reward_row(amount:, redeemed_at:)
    stub_request(:post, SnowflakeHelpers::STATEMENTS_URL)
      .with(body: /FROM rewards WHERE reward_id = 'rw_01'/)
      .to_return(status: 200, body: {
        "resultSetMetaData" => { "rowType" => [ { "name" => "AMOUNT" }, { "name" => "REDEEMED_AT" } ] },
        "data" => [ [ amount, redeemed_at ] ]
      }.to_json)
  end

  test "refuses to run outside development and changes nothing" do
    error = assert_raises(Demo::Reset::NotDevelopment) do
      Demo::Reset.new(client: snowflake_test_client).run
    end

    assert_includes error.message, "only runs in development"
    assert CdiWatermark.exists?(view_name: Warehouse::CdiPreview::VIEW)
    assert_not_requested :post, SnowflakeHelpers::STATEMENTS_URL
  end

  test "in development it re-runs the demo schema, clears the watermark and prints a summary" do
    stub_snowflake_ok
    stub_reward_row(amount: "25.00", redeemed_at: nil)

    summary = in_development { Demo::Reset.new(client: snowflake_test_client).run }

    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, body: /CREATE OR REPLACE SCHEMA/, times: 1
    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, body: /CREATE OR REPLACE VIEW/, times: 1
    assert_nil CdiWatermark.find_by(view_name: Warehouse::CdiPreview::VIEW)
    assert_equal "users=1 pending_exports=0 rails_demo_u1001_reward=unused ($25)", summary
  end

  test "the summary says when the RAILS_DEMO reward has been redeemed" do
    stub_snowflake_ok
    stub_reward_row(amount: "25.00", redeemed_at: "2026-11-02 16:00:37.840243")

    summary = in_development { Demo::Reset.new(client: snowflake_test_client).run }

    assert_includes summary, "rails_demo_u1001_reward=redeemed 2026-11-02 16:00:37.840243"
  end
end
