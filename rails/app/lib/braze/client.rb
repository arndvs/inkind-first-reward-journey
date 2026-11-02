module Braze
  # Sends /users/track bodies. The only supported mode is "record": it validates the body and returns
  # without any network call. The "http" mode is unverified against a live workspace (the trial has no
  # REST API). WebMock tests cover its request and response handling. See rails/ARCHITECTURE.md section 6.4.
  class Client
    MODES = %w[ record http ].freeze
    TRACK_PATH = "/users/track".freeze
    TIMEOUT_SECONDS = 30

    def initialize(mode: nil, endpoint: nil, api_key: nil)
      @mode = (mode || credential(:mode) || "record").to_s
      raise ArgumentError, "unknown Braze mode: #{@mode.inspect}" unless MODES.include?(@mode)

      @endpoint = endpoint || credential(:endpoint)
      @api_key = api_key || credential(:api_key)
    end

    # Returns {"message" => "recorded"} in record mode. In http mode returns Braze's response body.
    # A body with an "errors" array is a partial success; the caller keeps the errors.
    def track(payload)
      Validator.check!(payload)
      return { "message" => "recorded" } if @mode == "record"

      post_track(payload)
    end

    private

    def post_track(payload)
      raise ArgumentError, "http mode needs a Braze endpoint and api_key" if @endpoint.blank? || @api_key.blank?

      response = connection.post(TRACK_PATH) { |request| request.body = payload.to_json }
      handle(response)
    rescue Faraday::Error => error
      raise RetryableError, "Braze request did not complete: #{error.message}"
    end

    def connection
      @connection ||= Faraday.new(
        url: @endpoint,
        headers: {
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        },
        request: { timeout: TIMEOUT_SECONDS }
      )
    end

    def handle(response)
      status = response.status
      if status == 429 || status >= 500
        raise RetryableError, "Braze returned #{status}: #{response.body}"
      elsif status >= 400
        raise PermanentError, "Braze returned #{status}: #{response.body}"
      end

      parse(response.body)
    end

    def parse(raw)
      JSON.parse(raw.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def credential(key)
      Rails.application.credentials.dig(:braze, key)
    rescue ActiveSupport::EncryptedFile::MissingKeyError
      nil
    end
  end
end
