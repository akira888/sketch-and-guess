Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "rooms#index"

  resources :rooms, only: [ :index, :new, :create, :show ] do
    get :results, on: :member
    get :next_page, on: :member
  end

  get "entry/:room_id", to: "users#new", as: "user_entry"

  resources :users, only: [ :new, :create, :show ] do
    member do
      patch :decide_card
      patch :redraw_card
    end
  end

  resources :sketch_books, only: [ :new, :index, :show ] do
    post :add_page, on: :member
    resource :first_page, only: [ :new, :create, :show ]
    resources :pages, only: [ :new ]
  end
end
