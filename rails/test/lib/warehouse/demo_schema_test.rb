require "test_helper"

class WarehouseDemoSchemaTest < ActiveSupport::TestCase
  test "the real sql/10 file gives four statements in order, with no USE and no comments left" do
    statements = Warehouse::DemoSchema.statements

    assert_equal 4, statements.size
    assert statements[0].start_with?("CREATE OR REPLACE SCHEMA INKIND_POC.RAILS_DEMO CLONE INKIND_POC.FIRST_REWARD")
    assert statements[1].start_with?("ALTER TABLE app_events ADD COLUMN IF NOT EXISTS event_key")
    assert statements[2].start_with?("CREATE OR REPLACE VIEW braze_first_reward_attributes")
    assert statements[3].start_with?("SELECT COUNT(*)")
    assert statements.none? { |statement| statement.include?("--") }
    assert statements.none? { |statement| statement.start_with?("USE ") }
  end

  test "a semicolon inside a comment does not split a statement" do
    text = "-- note; with a semicolon\nSELECT 1;\n-- another; one\nSELECT 2;"

    assert_equal [ "SELECT 1", "SELECT 2" ], Warehouse::DemoSchema.statements(text)
  end

  test "reset sends each statement to Snowflake once, in order" do
    stub_snowflake_ok

    Warehouse::DemoSchema.reset!(client: snowflake_test_client)

    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, times: 4
    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, body: /ALTER TABLE app_events/, times: 1
    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL, body: /CREATE OR REPLACE VIEW/, times: 1
  end
end
