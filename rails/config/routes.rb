Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Solid Queue dashboard. Basic auth is off in development and on elsewhere.
  mount MissionControl::Jobs::Engine, at: "/admin/jobs"

  # Local QA console. See rails/ARCHITECTURE.md section 7.
  root "users#index"
  resources :users, only: %i[ index show ] do
    resources :saved_restaurants, only: :create
    resources :restaurant_views, only: :create
    resources :payments, only: :create
  end
  resources :deliveries, only: :index
end
