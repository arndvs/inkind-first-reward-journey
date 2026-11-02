require "test_helper"

class RewardTest < ActiveSupport::TestCase
  test "a user can have only one referral welcome reward" do
    user = create_user("u_1001")
    create_reward(user, key: "rw_a")

    assert_raises(ActiveRecord::RecordNotUnique) { create_reward(user, key: "rw_b") }
  end
end
