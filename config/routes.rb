require "resque/server"

Shipit::Application.routes.draw do
  root :to => 'stacks#index'

  mount Resque::Server.new, :at => "/resque"

  scope :authentication, controller: :authentication do
    post :finalize
    get :logout
  end

  resources :stacks, :only => [:new, :create, :index] do
    resource :webhooks, :only => [] do
      post :push, :state
    end
  end

  resources :stacks, :path => "/", :id => %r{[^/]+/[^/]+/[^/]+}, :only => [:show, :destroy] do
    member do
      get :settings
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
