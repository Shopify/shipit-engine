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
  resources :stacks, path: "/", id: %r{[^/]+/[^/]+/[^/]+}, only: %i(show destroy update) do
    member do
      get :settings
      post :sync_commits
      post :refresh_statuses
      post :sync_webhooks
      post :clear_git_cache
    end

    resources :commits, id: /\d+/, only: :show

    resources :rollbacks, id: /\d+/, only: %i(create)

    resources :deploys, id: /\d+/, only: %i(new show create) do
      member do
        get :rollback
      end
      resources :chunks, id: /\d+/, only:  %i(index), defaults: {format: :json} do
        collection do
          get :tail
        end
      end
    end
  end
end
