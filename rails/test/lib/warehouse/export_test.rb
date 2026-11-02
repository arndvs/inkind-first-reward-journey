require "test_helper"

class WarehouseExportTest < ActiveSupport::TestCase
  setup do
    @user = create_user("u_1001")
    @lantern = create_restaurant("r_101")
    @reward = create_reward(@user, key: "rw_01", min_spend_cents: 5000, amount_cents: 2500)
  end

  def export
    Warehouse::Export.new(client: snowflake_test_client, now: Time.utc(2026, 11, 2, 9, 0, 0)).run
  end

  def make_payment(subtotal_cents: 6240, key: "tx_export")
    Txn.create!(transaction_key: key, user: @user, restaurant: @lantern,
                subtotal_cents: subtotal_cents, tip_cents: 0, reward_applied: false)
  end

  test "with nothing pending the export makes no Snowflake call" do
    Txn.update_all(exported_at: Time.current)
    AppEvent.update_all(exported_at: Time.current)
    Reward.update_all(exported_at: Time.current)
    stub_snowflake_ok

    assert_equal({}, export)
    assert_not_requested :post, SnowflakeHelpers::STATEMENTS_URL
  end

  test "a new transaction is inserted with TEXT bindings and marked exported" do
    stub_snowflake_ok
    txn = make_payment

    export

    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, body: /MERGE INTO transactions/, times: 1
    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL,
                     body: /"value":"tx_export"/, times: 1
    assert_not_nil txn.reload.exported_at
  end

  test "transaction inserts are split into batches of 100" do
    stub_snowflake_ok
    101.times { |i| make_payment(key: "tx_batch_#{i}") }

    export

    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, body: /MERGE INTO transactions/, times: 2
  end

  test "a reward is merged by key with its amount and minimum as text" do
    stub_snowflake_ok

    export

    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, body: /MERGE INTO rewards/, times: 1
    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, body: /"value":"rw_01"/, times: 1
    assert_not_nil @reward.reload.exported_at
  end

  test "a failed statement leaves its rows pending and does not mark them exported" do
    # WebMock uses the most recent matching stub, so the failing one is declared last.
    stub_snowflake_ok
    stub_request(:post, SnowflakeHelpers::STATEMENTS_URL)
      .with(body: /MERGE INTO rewards/)
      .to_return(status: 500, body: { message: "warehouse unavailable" }.to_json)
    txn = make_payment

    assert_raises(Snowflake::Error) { export }

    assert_not_nil txn.reload.exported_at, "the transaction statement succeeded, so it is marked"
    assert_nil @reward.reload.exported_at, "the failed MERGE must leave the reward pending"
  end

  test "a reward redeemed after its export is sent again" do
    stub_snowflake_ok
    @reward.update!(exported_at: Time.utc(2026, 11, 1, 0, 0, 0))
    assert_equal({}, export, "an exported, unredeemed reward is not pending")
    assert_not_requested :post, SnowflakeHelpers::STATEMENTS_URL

    @reward.update!(redeemed_at: Time.utc(2026, 11, 2, 8, 0, 0))
    export

    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, body: /MERGE INTO rewards/, times: 1
    assert_operator @reward.reload.exported_at, :>, Time.utc(2026, 11, 2, 8, 0, 0)
  end

  test "the warehouse timestamp is UTC, not the session time zone" do
    stub_snowflake_ok
    make_payment

    export

    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL,
                     body: /MERGE INTO transactions.*CONVERT_TIMEZONE\('UTC'/, times: 1
  end

  test "each insert has one placeholder per bound value" do
    assert_equal 2 * Warehouse::Statements::TRANSACTION_BINDS, Warehouse::Statements.transactions_merge(2).count("?")
  end
end
