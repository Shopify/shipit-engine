require "resque/server"

Shipit::Application.routes.draw do
  root to: 'stacks#index'

  mount Resque::Server.new, at: "/resque"
  mount UserRequiredMiddleware.new(Pubsubstub::StreamAction.new), at: "/events", as: :events

  scope '/auth/:provider', as: :authentication, controller: :authentication do
    get '/', action: :mock
    post :callback
    get :logout
  end

  # Robots
  resources :stacks, only: [:new, :create, :index] do
    resource :webhooks, only: [] do
      post :push, :state
    end
  end

  # Humans
  resources :stacks, path: "/", id: %r{[^/]+/[^/]+/[^/]+}, only: %i(show destroy update) do
    member do
      get :settings
      post :sync_commits
      post :sync_webhooks
      post :clear_git_cache
    end

    resources :commits, id: /\d+/, only: :show

    resources :deploys, id: /\d+/, only:  [:new, :show, :create] do
      resources :chunks, id: /\d+/, only:  [:index], defaults: {format: :json} do
        collection do
          get :tail
        end
      end
    end
  end
end
