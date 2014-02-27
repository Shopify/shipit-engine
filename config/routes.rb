Shipit::Application.routes.draw do
  root :to => 'stacks#index'

  resources :stacks, :except => [:edit, :update] do
    resources :deploys, only: %i(show create)
    member do
      get :settings
    end

    resource :webhooks, :only => [] do
      post :push, :state
    end
  end
end
