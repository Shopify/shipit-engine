require "resque/server"

Shipit::Application.routes.draw do
  root to: 'stacks#index'

  mount UserRequiredMiddleware.new(Resque::Server.new), at: "/resque"
  mount UserRequiredMiddleware.new(Pubsubstub::StreamAction.new), at: "/events", as: :events

  get '/status/version' => 'status#version', as: :version

  scope '/auth/:provider', as: :authentication, controller: :authentication do
    get '/', action: :mock
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

  # Humans
  scope '/*id', id: %r{[^/]+/[^/]+/[^/]+}, as: :stack do
    get '/' => 'stacks#show'
    put '/' => 'stacks#update'
    delete '/' => 'stacks#destroy'
    get :settings, controller: :stacks
    post :sync_commits, controller: :stacks
    post :refresh_statuses, controller: :stacks
    post :sync_webhooks, controller: :stacks
    post :clear_git_cache, controller: :stacks
  end

  scope '/*stack_id', stack_id: %r{[^/]+/[^/]+/[^/]+}, as: :stack do
    resources :commits, only: :show

    resources :rollbacks, only: %i(create)

    resources :deploys, only: %i(new show create) do
      member do
        get :rollback
      end
      resources :chunks, only:  %i(index), defaults: {format: :json} do
        collection do
          get :tail
        end
      end
    end
  end
end
