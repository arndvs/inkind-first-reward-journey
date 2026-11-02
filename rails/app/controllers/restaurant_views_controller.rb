class RestaurantViewsController < ApplicationController
  def create
    user = User.find(params[:user_id])
    restaurant = Restaurant.find_by(id: params.expect(restaurant_view: [ :restaurant_id ])[:restaurant_id])
    return render_user_page_with_errors(user, [ "Choose a restaurant." ]) if restaurant.nil?

    AppEvent.create!(user: user, event_name: "restaurant_viewed", restaurant: restaurant, occurred_at: Time.current)
    redirect_to user_path(user), notice: "Recorded a view of #{restaurant.name}."
  end
end
