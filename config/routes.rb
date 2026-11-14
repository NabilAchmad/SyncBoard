Rails.application.routes.draw do
  root "projects#index"
  get "/dashboard", to: redirect("/")

  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resources :passwords, param: :token
  resource :profile, only: %i[edit update]

  resources :teams, only: %i[index create update] do
    collection do
      post :join
    end
    member do
      post :switch
      post :regenerate_code
      delete :leave
    end
  end

  resources :team_members, only: %i[index update destroy]

  resources :projects, only: %i[index new create show edit update] do
    member do
      patch :complete
    end

    resources :tasks, only: %i[create edit update destroy] do
      member do
        patch :move
      end
    end

    resources :meetings, only: %i[create show] do
      member do
        patch :save_transcript
        post :generate_summary
        patch :toggle_item
        post :add_action_item
        patch :update_action_item
        post :end_call
        post :approve
        post :reject
      end

      resources :meeting_messages, only: :create
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
