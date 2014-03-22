require "resque/server"

Shipit::Application.routes.draw do
  root :to => 'stacks#index'

  mount Resque::Server.new, :at => "/resque"

  scope '/auth/:provider', as: :authentication, controller: :authentication do
    get '/', action: :mock
    post :callback
    get :logout
  end

  # Robots
  resources :stacks, :only => [:new, :create, :index] do
    resource :webhooks, :only => [] do
      post :push, :state
    end
  end

  # Humans
  resources :stacks, :path => "/", :id => %r{[^/]+/[^/]+/[^/]+}, :only => [:show, :destroy] do
    member do
      get :settings
      post :sync_commits
      post :sync_webhooks
      post :clear_git_cache
    end

    resources :deploys, :id => /\d+/, :only =>  [:new, :show, :create] do
      resources :chunks, :id => /\d+/, :only =>  [:index], defaults: {format: :json} do
        collection do
          get :tail
        end
      end
    end
  end
end
