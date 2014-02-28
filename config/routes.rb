Shipit::Application.routes.draw do
  root :to => 'stacks#index'

  resources :stacks, :only => [:new, :create, :index]

  resources :stacks, :path => "/", :id => %r{[^/]+/[^/]+/[^/]+}, :only => [:show, :destroy] do
    member do
      get :settings
    end

    resources :deploys, :id => /\d+/, :only =>  [:show, :create]

    resource :webhooks, :id => /\d+/, :only => [] do
      post :push, :state
    end
  end
end
