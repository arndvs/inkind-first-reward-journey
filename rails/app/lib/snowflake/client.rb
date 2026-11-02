module Snowflake
  # Runs one SQL statement through the Snowflake SQL API with a key-pair JWT. Every bound value is sent
  # as TEXT and cast in the SQL (for example ?::NUMBER(10,2)). See rails/ARCHITECTURE.md section 6.7.
  class Client
    STATEMENTS_PATH = "/api/v2/statements".freeze
    TIMEOUT_SECONDS = 60
    POLL_INTERVAL_SECONDS = 1
    POLL_TIMEOUT_SECONDS = 30

    def initialize(config: default_config, jwt: nil, poll_interval: POLL_INTERVAL_SECONDS,
                   poll_timeout: POLL_TIMEOUT_SECONDS, sleeper: Kernel.method(:sleep), connection: nil)
      @config = config.symbolize_keys
      @jwt = jwt || Jwt.new(
        account: @config.fetch(:account),
        user: @config.fetch(:user),
        private_key_path: @config[:private_key_path],
        passphrase: @config[:private_key_passphrase]
      )
      @poll_interval = poll_interval
      @poll_timeout = poll_timeout
      @sleeper = sleeper
      @connection = connection
    end

    # Returns an array of hashes keyed by the column names Snowflake reports.
    def query(statement, bindings = [])
      status, body = post_statement(statement, bindings)
      body = poll(body.fetch("statementHandle")) if status == 202
      rows(body)
    end

    private

    def default_config
      Rails.application.credentials.snowflake || {}
    end

    def post_statement(statement, bindings)
      body = {
        statement: statement,
        timeout: TIMEOUT_SECONDS,
        warehouse: @config[:warehouse],
        database: @config[:database],
        schema: @config[:schema],
        role: @config[:role],
        bindings: bindings_for(bindings)
      }
      unpack(connection.post(STATEMENTS_PATH) { |request| request.body = body.to_json })
    end

    # A 202 means the statement is still running. Poll its handle until it finishes or time runs out.
    def poll(handle)
      waited = 0
      loop do
        if waited >= @poll_timeout
          raise Error, "Snowflake statement #{handle} is still running after #{@poll_timeout}s"
        end

        @sleeper.call(@poll_interval)
        waited += @poll_interval
        status, body = unpack(connection.get("#{STATEMENTS_PATH}/#{handle}"))
        return body if status == 200
      end
    end

    def bindings_for(values)
      values.each_with_index.to_h do |value, index|
        [ (index + 1).to_s, { "type" => "TEXT", "value" => value.nil? ? nil : value.to_s } ]
      end
    end

    def rows(body)
      columns = body.dig("resultSetMetaData", "rowType").map { |column| column["name"] }
      Array(body["data"]).map { |values| columns.zip(values).to_h }
    end

    # Returns [status, body] for 200 and 202. Anything else raises Snowflake::Error with Snowflake's message and code.
    def unpack(response)
      body = parse(response.body)
      return [ response.status, body ] if [ 200, 202 ].include?(response.status)

      raise Error.new(body["message"] || "Snowflake returned #{response.status}", code: body["code"])
    end

    def parse(raw)
      raw.blank? ? {} : JSON.parse(raw)
    rescue JSON::ParserError
      {}
    end

    def connection
      @connection ||= Faraday.new(
        url: "https://#{host}",
        headers: {
          "Authorization" => "Bearer #{@jwt.token}",
          "X-Snowflake-Authorization-Token-Type" => "KEYPAIR_JWT",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        },
        request: { timeout: TIMEOUT_SECONDS }
      )
    end

    def host
      "#{@config.fetch(:account).downcase.tr('_', '-')}.snowflakecomputing.com"
    end
  end
end
