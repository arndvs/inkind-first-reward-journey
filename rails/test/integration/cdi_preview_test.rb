require "test_helper"

class CdiPreviewPageTest < ActionDispatch::IntegrationTest
  COLUMNS = %w[ EXTERNAL_ID UPDATED_AT PAYLOAD ].freeze

  # The controller builds its own Snowflake client. Hand it the test client, so no credentials or key file are read.
  def get_with_test_client(path)
    Snowflake::Client.stub(:new, snowflake_test_client) { get path }
  end

  def post_with_test_client(path, **options)
    Snowflake::Client.stub(:new, snowflake_test_client) { post path, **options }
  end

  def stub_preview(rows)
    body = {
      "resultSetMetaData" => { "rowType" => COLUMNS.map { |name| { "name" => name } } },
      "data" => rows
    }.to_json
    stub_request(:post, SnowflakeHelpers::STATEMENTS_URL).to_return(status: 200, body: body)
  end

  test "the page shows the rows Cloud Data Ingestion would pick up, with the honest label" do
    payload = { first_reward_amount: nil, first_transaction_at: "2026-11-02 16:00:37.837402" }.to_json
    stub_preview([ [ "u_1001", "1793596440.000000000", payload ] ])

    get_with_test_client warehouse_cdi_preview_path

    assert_response :success
    assert_includes response.body, "u_1001"
    assert_includes response.body, "would pick up on its next sync"
    assert_includes response.body, "Braze runs the real sync"
    assert_includes response.body, "null"
  end

  test "marking synced stores the newest time shown" do
    stub_preview([])

    post_with_test_client warehouse_cdi_mark_synced_path, params: { synced_through: "2026-11-02T16:00:40Z" }

    assert_redirected_to warehouse_cdi_preview_path
    assert_equal Time.utc(2026, 11, 2, 16, 0, 40),
                 CdiWatermark.find_by!(view_name: "braze_first_reward_attributes").synced_through
  end

  test "a time that is not a time is refused and nothing is stored" do
    post_with_test_client warehouse_cdi_mark_synced_path, params: { synced_through: "not a time" }

    assert_redirected_to warehouse_cdi_preview_path
    assert_nil CdiWatermark.find_by(view_name: "braze_first_reward_attributes")
  end
end
