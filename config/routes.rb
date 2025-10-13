Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root path
  resources :projects
  root "projects#index"

  # Sessions
  get  "/login",  to: "sessions#new",    as: :login
  post "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout

  # Main resources
  resources :users do
    member do
      patch :soft_delete
    end
  end

  resources :projects do
    member do
      patch :soft_delete
    end
    resources :tasks, except: [ :index ] do
      member do
        patch :soft_delete
      end
      resources :test_cases do
        member do
          patch :soft_delete
        end
      end
      resources :bugs, except: [ :index ] do
        member do
          patch :soft_delete
        end
      end
      resources :test_runs, except: [ :index ] do
        member do
          patch :soft_delete
        end
      end
    end
  end

  # Standalone resources (for index pages with filters)
  resources :tasks, only: [ :index ]
  resources :test_cases, only: [ :index ]
  resources :bugs, only: [ :index ]
  resources :test_runs, only: [ :index ]

  # Test environments
  resources :test_environments do
    member do
      patch :soft_delete
    end
  end

  # Test results
  resources :test_results do
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
  resources :test_steps do
    resources :test_step_contents
  end

  # Histories (read-only)
  resources :test_case_histories, only: [ :index, :show ]
  resources :task_histories, only: [ :index, :show ]
end
