Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :participants, only: :index
  get "checkout", to: "checkouts#new"
  post "checkout", to: "checkouts#create"

  root "participants#index"
end
