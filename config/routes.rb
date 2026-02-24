Rails.application.routes.draw do
  # Action Cable
  mount ActionCable.server => "/cable"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root
  root "dashboard#index"

  # Devise routes for User authentication (must be BEFORE resources :users to avoid conflict)
  devise_for :users, path: "", path_names: {
    sign_in: "login",
    sign_out: "logout",
    sign_up: "register"
  }

  # Authentication (Google OAuth - có thể giữ lại nếu cần)
  namespace :auth do
    # Google OAuth
    get "google/callback", to: "google#callback"
    post "google/callback", to: "google#callback"
  end

  # Dashboard
  get "dashboard", to: "dashboard#index"
  get "admin/dashboard", to: "dashboard#admin", as: :admin_dashboard
  get "user/dashboard", to: "dashboard#user", as: :user_dashboard
  get "profile/password", to: "profiles#edit_password", as: :edit_password
  patch "profile/password", to: "profiles#update_password", as: :update_password

  # Main resources
  resources :users do
    member do
      patch :soft_delete
    end
  end

  resources :projects do
    collection do
      get :archived
    end
    member do
      patch :soft_delete
      patch :restore
    end
    resources :daily_import_runs, only: [ :index, :show ]
    resources :tasks do
      member do
        patch :soft_delete
        patch :restore
        post :create_subtask
        post :promote_to_subtask
        post :promote_all_to_subtask
        post :update_device_config
      end
      collection do
        get :list_redmine_issues
        get :redmine_projects
        post :import_from_redmine
        post :import_from_redmine_url
        post :import_selected_redmine_issues
      end
      resources :test_cases do
        member do
          patch :soft_delete
          patch :restore
          get :history
          post :revert
        end
        collection do
          post :import_from_sheet
        end
        resources :test_steps, only: [:create, :edit, :update, :destroy]
        resources :test_results, only: [ :new, :create, :edit, :update, :destroy ] do
          member do
            patch :soft_delete
          end
        end
      end
      resources :bugs do
        member do
          patch :soft_delete
          patch :restore
          get :history
        end
        collection do
          post :import_from_sheet
        end
      end
      resources :test_runs, except: [ :index ] do
        member do
          patch :soft_delete
          post :start
          post :complete
          post :abort
        end
      end
    end
  end

  # Standalone resources (for index pages with filters)
  resources :tasks, only: [ :index ]
  resources :test_cases, only: [ :index ]
  resources :bugs, only: [ :index ]
  resources :test_runs, only: [ :index ]

  # Test results (index, show, soft_delete)
  resources :test_results do
    member do
      patch :soft_delete
    end
  end

  # Test environments
  resources :test_environments do
    member do
      patch :soft_delete
    end
  end

  # Bug evidences
  resources :bug_evidences do
    member do
      patch :soft_delete
    end
  end

  # Test steps and contents
  resources :test_steps, shallow: true do
    resources :test_step_contents, only: [:update]
  end

  resources :test_step_contents, only: [:update]

  # Histories (read-only)
  resources :test_case_histories, only: [ :index, :show ]
  resources :task_histories, only: [ :index, :show ]
  resources :project_histories, only: [ :index, :show ]
  resource :app_configuration, only: [:edit, :update]

  # Global notifications (header dropdown)
  resources :notifications, only: [:index] do
    collection do
      get :unread_count
      post :mark_all_read
    end
    member do
      get :read_and_go  
      post :mark_read
    end
  end
end
