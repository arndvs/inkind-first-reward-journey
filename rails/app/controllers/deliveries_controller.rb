class DeliveriesController < ApplicationController
  def index
    @deliveries = BrazeDelivery.includes(:user).order(created_at: :desc)
  end
end
