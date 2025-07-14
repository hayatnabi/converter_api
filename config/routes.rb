Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  namespace :api do
    namespace :v1 do
      get 'convert', to: 'converter#convert'
      get 'currencies', to: 'converter#currencies' # <-- for fetching available currencies list
      get 'unit_convert', to: 'converter#unit_convert' # Area/Volume
      get 'usage_log', to: 'converter#usage_log'       # Usage Analytics
    end
  end
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
