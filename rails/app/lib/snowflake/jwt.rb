require "base64"

module Snowflake
  # Key-pair JWT for the SQL API (RS256). Cached for 50 minutes; each token is valid for 59.
  # Follows Snowflake's key-pair authentication docs. See rails/ARCHITECTURE.md section 6.7.
  class Jwt
    LIFETIME = 59.minutes
    CACHE_FOR = 50.minutes

    def initialize(account:, user:, private_key: nil, private_key_path: nil, passphrase: nil)
      @account = account.to_s.upcase
      @user = user.to_s.upcase
      @private_key = private_key
      @private_key_path = private_key_path
      @passphrase = passphrase.presence
    end

    def token
      refresh! if @token.nil? || Time.now >= @token_renews_at
      @token
    end

    private

    def refresh!
      now = Time.now.to_i
      claims = {
        iss: "#{qualified_name}.SHA256:#{fingerprint}",
        sub: qualified_name,
        iat: now,
        exp: now + LIFETIME.to_i
      }
      @token = JWT.encode(claims, key, "RS256")
      @token_renews_at = Time.now + CACHE_FOR
    end

    def qualified_name
      "#{@account}.#{@user}"
    end

    def key
      @key ||= @private_key || OpenSSL::PKey.read(File.read(@private_key_path), @passphrase)
    end

    # SHA-256 of the public key's DER, base64-encoded. Snowflake matches it to the key registered on the user.
    def fingerprint
      Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(key.public_key.to_der))
    end
  end
end
