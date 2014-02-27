Shipit::Application.routes.draw do
  resources :stacks, :only => [:index, :show, :create, :destroy] do
    resource :webhooks, :only => [] do
      post :push, :state
    end
  end
end
