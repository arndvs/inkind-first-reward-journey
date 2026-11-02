require "test_helper"

class SnowflakeJwtTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @key = OpenSSL::PKey::RSA.new(2048) # generated for the test only; never a real key
    @jwt = Snowflake::Jwt.new(account: "jkxhacw-zf92105", user: "arndvs", private_key: @key)
  end

  def decode(token)
    JWT.decode(token, @key.public_key, true, algorithm: "RS256").first
  end

  test "the token is RS256 and verifies with the public key" do
    header = JWT.decode(@jwt.token, @key.public_key, true, algorithm: "RS256").last

    assert_equal "RS256", header["alg"]
  end

  test "iss carries the uppercased account, user and the public key fingerprint" do
    fingerprint = Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(@key.public_key.to_der))

    assert_equal "JKXHACW-ZF92105.ARNDVS.SHA256:#{fingerprint}", decode(@jwt.token)["iss"]
  end

  test "sub is the uppercased account and user" do
    assert_equal "JKXHACW-ZF92105.ARNDVS", decode(@jwt.token)["sub"]
  end

  test "the token lives for 59 minutes" do
    claims = decode(@jwt.token)

    assert_equal 59 * 60, claims["exp"] - claims["iat"]
  end

  test "the token is cached for 50 minutes, then renewed" do
    travel_to Time.utc(2026, 11, 2, 8, 0, 0) do
      first = @jwt.token

      travel 49.minutes
      assert_equal first, @jwt.token

      travel 2.minutes
      assert_not_equal first, @jwt.token
    end
  end

  test "a key file path is read and an encrypted key uses the passphrase" do
    path = Rails.root.join("tmp", "jwt-test-key.pem").to_s
    File.write(path, @key.to_pem)
    jwt = Snowflake::Jwt.new(account: "JKXHACW-ZF92105", user: "ARNDVS", private_key_path: path)

    assert_equal "JKXHACW-ZF92105.ARNDVS", decode(jwt.token)["sub"]
  ensure
    FileUtils.rm_f(path)
  end
end
