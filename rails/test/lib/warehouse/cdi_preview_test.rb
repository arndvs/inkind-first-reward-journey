require "test_helper"

class WarehouseCdiPreviewTest < ActiveSupport::TestCase
  COLUMNS = %w[ EXTERNAL_ID UPDATED_AT PAYLOAD ].freeze

  # The SQL API returns TIMESTAMP_NTZ as epoch seconds with nanoseconds, and VARIANT as a JSON string.
  def preview_response(rows)
    {
      "resultSetMetaData" => { "rowType" => COLUMNS.map { |name| { "name" => name } } },
      "data" => rows
    }.to_json
  end

  def preview
    Warehouse::CdiPreview.new(client: snowflake_test_client)
  end

  test "rows parse the payload JSON and the UPDATED_AT time" do
    payload = { first_reward_amount: nil, first_transaction_at: "2026-11-02 16:00:37.837402" }.to_json
    stub_request(:post, SnowflakeHelpers::STATEMENTS_URL).to_return(
      status: 200, body: preview_response([ [ "u_1001", "1793596440.000000000", payload ] ])
    )

    row = preview.rows.first

    assert_equal "u_1001", row[:external_id]
    assert_equal Time.at(1_793_596_440).utc, row[:updated_at]
    assert_equal({ "first_reward_amount" => nil, "first_transaction_at" => "2026-11-02 16:00:37.837402" }, row[:payload])
  end

  test "the first query starts from the epoch watermark, in UTC" do
    stub_request(:post, SnowflakeHelpers::STATEMENTS_URL).to_return(status: 200, body: preview_response([]))

    preview.rows

    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL,
                     body: /"value":"1970-01-01 00:00:00.000000"/, times: 1
  end

  test "marking synced moves the watermark, and the next query uses it" do
    stub_request(:post, SnowflakeHelpers::STATEMENTS_URL).to_return(status: 200, body: preview_response([]))

    preview.mark_synced!(Time.utc(2026, 11, 2, 16, 0, 40))
    preview.rows

    assert_requested :post, SnowflakeHelpers::STATEMENTS_URL,
                     body: /"value":"2026-11-02 16:00:40.000000"/, times: 1
  end

  test "the watermark is stored under the view name" do
    preview.mark_synced!(Time.utc(2026, 11, 2, 16, 0, 40))

    assert_equal Time.utc(2026, 11, 2, 16, 0, 40), CdiWatermark.find_by!(view_name: "braze_first_reward_attributes").synced_through
  end
end
