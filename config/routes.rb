Shipit::Application.routes.draw do
  resources :stacks, :except => [:edit, :update] do
    resource :webhooks, :only => [] do
      post :push, :state
    end
  end
end
