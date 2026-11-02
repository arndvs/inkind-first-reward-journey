require "test_helper"

class SavedRestaurantTest < ActiveSupport::TestCase
  setup do
    @user = create_user("u_1001")
    @restaurant = create_restaurant("r_201")
    SavedRestaurant.create!(user: @user, restaurant: @restaurant)
  end

  test "the same restaurant can't be saved twice by one user" do
    assert_not SavedRestaurant.new(user: @user, restaurant: @restaurant).valid?
  end

  test "the database also refuses a duplicate pair" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      SavedRestaurant.new(user: @user, restaurant: @restaurant).save(validate: false)
    end
  end
end
