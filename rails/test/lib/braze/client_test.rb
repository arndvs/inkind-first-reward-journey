require "test_helper"

class BrazeClientTest < ActiveSupport::TestCase
  ENDPOINT = "https://rest.braze.test".freeze
  TRACK_URL = "#{ENDPOINT}/users/track".freeze
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze
  PAYLOAD = {
    "events" => [
      {
        "external_id" => "u_123",
        "name" => "restaurant_saved",
        "time" => "2026-10-24T18:02:00Z",
        "properties" => { "restaurant_id" => "r_456" }
      }
    ]
  }.freeze

  def http_client
    Braze::Client.new(mode: "http", endpoint: ENDPOINT, api_key: "test-key")
  end

  test "record mode returns recorded and makes no network call" do
    result = Braze::Client.new(mode: "record").track(PAYLOAD)

    assert_equal({ "message" => "recorded" }, result)
    assert_not_requested :post, TRACK_URL
  end

  test "record mode still validates the payload" do
    bad = { "events" => [ { "external_id" => "u_123", "name" => "x" } ] }

    assert_raises(Braze::InvalidPayload) { Braze::Client.new(mode: "record").track(bad) }
  end

  test "an unknown mode is refused" do
    assert_raises(ArgumentError) { Braze::Client.new(mode: "live") }
  end

  test "http mode posts the payload with a bearer token and JSON body" do
    stub_request(:post, TRACK_URL)
      .with(headers: { "Authorization" => "Bearer test-key", "Content-Type" => "application/json" }, body: PAYLOAD)
      .to_return(status: 201, body: '{"message":"success"}', headers: JSON_HEADERS)

    result = http_client.track(PAYLOAD)

    assert_equal "success", result["message"]
    assert_requested :post, TRACK_URL, times: 1
  end

  test "http mode validates before it sends anything" do
    bad = { "purchases" => [ { "external_id" => "u_123" } ] }

    assert_raises(Braze::InvalidPayload) { http_client.track(bad) }
    assert_not_requested :post, TRACK_URL
  end

  test "http mode without an endpoint or key is refused" do
    assert_raises(ArgumentError) { Braze::Client.new(mode: "http").track(PAYLOAD) }
  end

  test "429 is retryable" do
    stub_request(:post, TRACK_URL).to_return(status: 429, body: "slow down")

    assert_raises(Braze::RetryableError) { http_client.track(PAYLOAD) }
  end

  test "5xx is retryable" do
    stub_request(:post, TRACK_URL).to_return(status: 503, body: "unavailable")

    assert_raises(Braze::RetryableError) { http_client.track(PAYLOAD) }
  end

  test "other 4xx is permanent" do
    stub_request(:post, TRACK_URL).to_return(status: 400, body: '{"message":"bad"}')

    assert_raises(Braze::PermanentError) { http_client.track(PAYLOAD) }
  end

  test "a timeout is retryable" do
    stub_request(:post, TRACK_URL).to_timeout

    assert_raises(Braze::RetryableError) { http_client.track(PAYLOAD) }
  end

  test "a 201 with an errors array is a partial success that keeps the errors" do
    errors = [ { "type" => "INVALID_ENTRY", "index" => 0 } ]
    stub_request(:post, TRACK_URL).to_return(
      status: 201, body: { "message" => "success", "errors" => errors }.to_json, headers: JSON_HEADERS
    )

    result = http_client.track(PAYLOAD)

    assert_equal "success", result["message"]
    assert_equal errors, result["errors"]
  end
end
