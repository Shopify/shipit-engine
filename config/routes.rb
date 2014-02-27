Shipit::Application.routes.draw do
  root :to => 'stacks#index'

  resources :stacks, :only => [:new, :create, :index]

  resources :stacks, :path => "/", :id => %r{[^/]+/[^/]+/[^/]+}, :only => [:show, :destroy] do
    member do
      get :settings
    end

    resources :deploys, only: %i(show create)

    resource :webhooks, :only => [] do
      post :push, :state
    end
  end
end
