Shipit::Engine.routes.draw do
  stack_id_format = %r{[^/]+/[^/]+/[^/]+}
  sha_format = /[\da-f]{6,40}/
  root to: 'stacks#index'

  mount Pubsubstub::StreamAction.new, at: "/events", as: :events

  get '/status/version' => 'status#version', as: :version

  scope '/github/auth/github', as: :github_authentication, controller: :github_authentication do
    get '/', action: :request
    post :callback
    get :callback
    get :logout
  end

  # Robots
  resources :stacks, only: %i(new create index) do
    resource :webhooks, only: [] do
      post :push, :state
    end
  end

  resources :webhooks, only: [] do
    collection do
      post :membership
      get :membership
    end
  end

  # Humans
  scope '/*id', id: stack_id_format, as: :stack do
    get '/' => 'stacks#show'
    patch '/' => 'stacks#update'
    delete '/' => 'stacks#destroy'
    get :settings, controller: :stacks
    post :refresh, controller: :stacks
    get :refresh, controller: :stacks # For easier design, sorry :/
    post :sync_webhooks, controller: :stacks
    post :clear_git_cache, controller: :stacks
  end

  scope '/*stack_id', stack_id: stack_id_format, as: :stack do
    get '/commit/:sha/checks/tail' => 'commit_checks#tail', as: :tail_commit_checks, defaults: {format: :json}

    resources :rollbacks, only: %i(create)
    resources :tasks, only: %i(show) do
      collection do
        get '' => 'tasks#index', as: :index
        get ':definition_id/new' => 'tasks#new', as: :new
        post ':definition_id' => 'tasks#create', as: ''
      end

      member do
        post :abort
      end

      resources :chunks, only:  %i(index), defaults: {format: :json} do
        collection do
          get :tail
        end
      end
    end

    resources :deploys, only: %i(show create) do
      get ':sha', sha: sha_format, on: :new, action: :new, as: ''
      member do
        get :rollback
      end
    end
  end

  # API
  namespace :api do
    root to: 'base#index'
    resources :stacks, only: :index
    scope '/stacks/*id', id: stack_id_format, as: :stack do
      get '/' => 'stacks#show'
    end

    scope '/stacks/*stack_id', stack_id: stack_id_format, as: :stack do
      resource :lock, only: %i(create update destroy)
      resources :tasks, only: %i(index show) do
        resource :output, only: :show
      end
      resources :deploys, only: %i(create)
      resources :hooks, only: %i(index create show update destroy)
    end

    resources :hooks, only: %i(index create show update destroy)
  end
end
