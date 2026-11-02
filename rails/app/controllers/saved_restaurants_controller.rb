class SavedRestaurantsController < ApplicationController
  def create
    user = User.find(params[:user_id])
    restaurant = Restaurant.find_by(id: params.expect(saved_restaurant: [ :restaurant_id ])[:restaurant_id])
    return render_user_page_with_errors(user, [ "Choose a restaurant." ]) if restaurant.nil?

    saved = user.saved_restaurants.build(restaurant: restaurant)
    if saved.save
      redirect_to user_path(user), notice: "Saved #{restaurant.name}."
    else
      render_user_page_with_errors(user, saved.errors.full_messages)
    end
  end
end
