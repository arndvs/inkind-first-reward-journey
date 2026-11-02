class UsersController < ApplicationController
  def index
    @users = User.includes(:rewards, :saved_restaurants, :transactions, :braze_deliveries).order(:external_id)
  end

  def show
    load_user_page(User.find(params[:id]))
  end
end
