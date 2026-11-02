require "test_helper"

class SnowflakeClientTest < ActiveSupport::TestCase
  ACCOUNT_HOST = "https://jkxhacw-zf92105.snowflakecomputing.com".freeze
  STATEMENTS = "#{ACCOUNT_HOST}/api/v2/statements".freeze
  CONFIG = {
    account: "JKXHACW-ZF92105",
    user: "ARNDVS",
    role: "SYSADMIN",
    warehouse: "INKIND_POC_WH",
    database: "INKIND_POC",
    schema: "RAILS_DEMO"
  }.freeze

  setup do
    @key = OpenSSL::PKey::RSA.new(2048) # generated for the test only
    @jwt = Snowflake::Jwt.new(account: CONFIG[:account], user: CONFIG[:user], private_key: @key)
    @sleeps = []
  end

  def client(**options)
    Snowflake::Client.new(
      config: CONFIG,
      jwt: @jwt,
      sleeper: ->(seconds) { @sleeps << seconds },
      **options
    )
  end

  def result(rows: [ [ "8.40.0" ] ], columns: [ "CURRENT_VERSION()" ])
    {
      "resultSetMetaData" => { "rowType" => columns.map { |name| { "name" => name } } },
      "data" => rows
    }.to_json
  end

  test "posts the statement with TEXT bindings and the session context" do
    stub = stub_request(:post, STATEMENTS)
           .with(
             body: {
               statement: "SELECT ? AS x",
               timeout: 60,
               warehouse: "INKIND_POC_WH",
               database: "INKIND_POC",
               schema: "RAILS_DEMO",
               role: "SYSADMIN",
               bindings: { "1" => { "type" => "TEXT", "value" => "hi" } }
             }
           )
           .to_return(status: 200, body: result(rows: [ [ "hi" ] ], columns: [ "X" ]))

    client.query("SELECT ? AS x", [ "hi" ])

    assert_requested stub
  end

  test "sends the key-pair JWT headers" do
    stub_request(:post, STATEMENTS)
      .with { |request| request.headers["Authorization"].start_with?("Bearer ") }
      .with(headers: { "X-Snowflake-Authorization-Token-Type" => "KEYPAIR_JWT" })
      .to_return(status: 200, body: result)

    assert_equal [ { "CURRENT_VERSION()" => "8.40.0" } ], client.query("SELECT CURRENT_VERSION()")
  end

  test "maps each row onto the column names from the result metadata" do
    stub_request(:post, STATEMENTS).to_return(
      status: 200,
      body: result(rows: [ [ "u_1001", "25.00" ] ], columns: %w[ EXTERNAL_ID AMOUNT ])
    )

    rows = client.query("SELECT EXTERNAL_ID, AMOUNT FROM t")

    assert_equal [ { "EXTERNAL_ID" => "u_1001", "AMOUNT" => "25.00" } ], rows
  end

  test "a 202 is polled until the statement finishes" do
    stub_request(:post, STATEMENTS).to_return(status: 202, body: { statementHandle: "h1" }.to_json)
    stub_request(:get, "#{STATEMENTS}/h1").to_return(
      { status: 202, body: { statementHandle: "h1" }.to_json },
      { status: 200, body: result }
    )

    rows = client.query("SELECT CURRENT_VERSION()")

    assert_equal [ { "CURRENT_VERSION()" => "8.40.0" } ], rows
    assert_equal [ 1, 1 ], @sleeps # one wait before each poll: the 202 poll, then the 200 poll
  end

  test "polling gives up after the timeout" do
    stub_request(:post, STATEMENTS).to_return(status: 202, body: { statementHandle: "h2" }.to_json)
    stub_request(:get, "#{STATEMENTS}/h2").to_return(status: 202, body: { statementHandle: "h2" }.to_json)

    error = assert_raises(Snowflake::Error) do
      client(poll_interval: 1, poll_timeout: 3).query("SELECT SLOW")
    end

    assert_includes error.message, "still running"
  end

  test "a 4xx raises Snowflake::Error with Snowflake's message and code" do
    stub_request(:post, STATEMENTS).to_return(
      status: 422, body: { code: "000904", message: "invalid identifier 'NOPE'" }.to_json
    )

    error = assert_raises(Snowflake::Error) { client.query("SELECT nope") }

    assert_equal "000904", error.code
    assert_includes error.message, "invalid identifier"
  end

  test "a 5xx raises Snowflake::Error" do
    stub_request(:post, STATEMENTS).to_return(status: 500, body: { message: "server error" }.to_json)

    assert_raises(Snowflake::Error) { client.query("SELECT 1") }
  end
end
