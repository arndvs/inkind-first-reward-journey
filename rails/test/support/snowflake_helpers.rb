# Shared by the warehouse tests. Every Snowflake call is stubbed with WebMock, so no test needs credentials.
module SnowflakeHelpers
  STATEMENTS_URL = "https://jkxhacw-zf92105.snowflakecomputing.com/api/v2/statements".freeze

  def snowflake_test_client
    jwt = Snowflake::Jwt.new(account: "JKXHACW-ZF92105", user: "ARNDVS", private_key: snowflake_test_key)
    Snowflake::Client.new(config: snowflake_test_config, jwt: jwt, sleeper: ->(_seconds) { })
  end

  def stub_snowflake_ok
    stub_request(:post, STATEMENTS_URL).to_return(status: 200, body: empty_result)
  end

  def empty_result
    { "resultSetMetaData" => { "rowType" => [] }, "data" => [] }.to_json
  end

  private

  def snowflake_test_key
    @snowflake_test_key ||= OpenSSL::PKey::RSA.new(2048) # generated for the test only
  end

  def snowflake_test_config
    {
      account: "JKXHACW-ZF92105", user: "ARNDVS", role: "SYSADMIN",
      warehouse: "INKIND_POC_WH", database: "INKIND_POC", schema: "RAILS_DEMO"
    }
  end
end
