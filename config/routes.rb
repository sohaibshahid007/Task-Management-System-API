Rails.application.routes.draw do
  # Devise routes for user authentication
  devise_for :users

  namespace :api do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      post "auth/signup", to: "auth#signup"
      post "auth/logout", to: "auth#logout"
      post "auth/password/reset", to: "auth#password_reset"

      resources :users, only: [ :index, :show, :update, :destroy ]

      resources :tasks do
        resources :comments, only: [ :index, :create ], shallow: true

        member do
          post :assign
          post :complete
          post :export
        end

        collection do
          get :dashboard
          get :overdue
        end
      end

      resources :comments, only: [ :destroy ]
    end

    namespace :v2 do
      resources :tasks, only: [ :index, :show, :update, :destroy ]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
  match "/api/*path", to: "errors#not_found", via: :all, constraints: lambda { |req| req.format.json? }
end
