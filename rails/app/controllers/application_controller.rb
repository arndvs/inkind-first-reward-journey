class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Loads what the user page shows. The show page and every form that re-renders it use this.
  def load_user_page(user)
    @user = user
    @saved = user.saved_restaurants.includes(:restaurant).order(:created_at)
    @deliveries = user.braze_deliveries.order(created_at: :desc)
    @restaurants = Restaurant.order(:name)
  end

  def render_user_page_with_errors(user, messages)
    load_user_page(user)
    @form_errors = messages
    render "users/show", status: :unprocessable_content
  end
end
