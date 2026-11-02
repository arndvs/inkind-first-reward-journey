require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is stripped and downcased" do
    user = User.create!(external_id: "u_norm", email: "  Ana@Example.COM ")

    assert_equal "ana@example.com", user.email
  end

  test "external_id is unique" do
    create_user("u_dup")

    assert_not User.new(external_id: "u_dup", email: "other@example.com").valid?
  end
end
