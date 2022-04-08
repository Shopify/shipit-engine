# frozen_string_literal: true
Shipit::Engine.routes.draw do
  stack_id_format = %r{[^/]+/[^/]+/[^/]+}
  repository_id_format = %r{[^/]+/[^/]+}
  sha_format = /[\da-f]{6,40}/
  root to: 'stacks#index'

  mount Pubsubstub::StreamAction.new, at: "/events", as: :events

  # Robots
  get '/status/version' => 'status#version', as: :version

  resources :webhooks, only: :create

  # API
  namespace :api do
    root to: 'base#index'
    resources :stacks, only: %i(index create)
    scope '/stacks/*id', id: stack_id_format, as: :stack do
      get '/' => 'stacks#show'
      delete '/' => 'stacks#destroy'
      patch '/' => 'stacks#update'
      post '/refresh' => 'stacks#refresh'
    end

    scope '/stacks/*stack_id', stack_id: stack_id_format, as: :stack do
      get '/ccmenu' => 'ccmenu#show', as: :ccmenu
      resource :lock, only: %i(create update destroy)
      resources :tasks, only: %i(index show) do
        resource :output, only: :show
        member do
          put :abort
        end
      end
      resources :deploys, only: %i(index create) do
        resources :release_statuses, only: %i(create)
      end
      resources :rollbacks, only: %i(create)
      resources :commits, only: %i(index)
      resources :merge_requests, only: %i(index show update destroy)
      post '/task/:task_name' => 'tasks#trigger', as: :trigger_task
      resources :hooks, only: %i(index create show update destroy)
    end

    resources :hooks, only: %i(index create show update destroy)
  end

  scope '/ccmenu/*stack_id', stack_id: stack_id_format, as: :ccmenu_url do
    get '/' => 'ccmenu_url#fetch'
  end

  # Browser extension
  get '/merge_status', action: :show, controller: :merge_status, as: :merge_status
  put '/merge_status/*stack_id/pull/:number', action: :enqueue, controller: :merge_status, id: stack_id_format, as: :enqueue_merge_request
  delete '/merge_status/*stack_id/pull/:number', action: :dequeue, controller: :merge_status, id: stack_id_format, as: :dequeue_merge_request

  # Humans
  resources :api_clients

  resources :repositories, only: %i(new index create)
  scope '/repositories/*id', id: repository_id_format, as: :repository do
    get '/' => 'repositories#show'
    patch '/' => 'repositories#update'
    delete '/' => 'repositories#destroy'
    get :settings, controller: :repositories
    get 'stacks/new' => 'repositories#new_stack'
  end

  scope '/github/auth/github', as: :github_authentication, controller: :github_authentication do
    get '/', action: :request
    post :callback
    get :callback
    get :logout
  end

  resources :stacks, only: %i(new create index)
  scope '/*id', id: stack_id_format, as: :stack do
    get '/' => 'stacks#show'
    patch '/' => 'stacks#update'
    delete '/' => 'stacks#destroy'
    get :settings, controller: :stacks
    get :all_tasks, controller: :stacks, as: :tasks_list
    get :statistics, controller: :stacks
    post :refresh, controller: :stacks
    get :refresh, controller: :stacks # For easier design, sorry :/
    post :clear_git_cache, controller: :stacks
  end

  scope '/task/:id', controller: :tasks do
    get '/', action: :lookup
  end

  scope '/*stack_id', stack_id: stack_id_format, as: :stack do
    get '/commit/:sha/checks' => 'commit_checks#show', as: :commit_checks
    get '/commit/:sha/checks/tail' => 'commit_checks#tail', as: :tail_commit_checks, defaults: { format: :json }

    get '/stats' => 'stats#show', as: :stats

    resources :rollbacks, only: %i(create)
    resources :commits, only: %i(update)
    resources :tasks, only: %i(show) do
      collection do
        get '' => 'tasks#index', as: :index
        get ':definition_id/new' => 'tasks#new', as: :new
        post ':definition_id' => 'tasks#create', as: ''
      end

      member do
        post :abort
        get :tail, defaults: { format: :json }
      end
    end

    resources :deploys, only: %i(show create) do
      get ':sha', sha: sha_format, on: :new, action: :new, as: ''
      member do
        get :rollback
        get :revert
      end

      resources :release_statuses, only: %i(create)
    end

    resources :merge_requests, only: %i(index destroy create)
  end
  get '/stacks/:id' => 'stacks#lookup'

  scope '/*repo', repo: %r{[^/]+/[^/]+}, as: :stack_search do
    get '/' => 'stacks#index'
  end
end
