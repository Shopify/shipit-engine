Shipit::Application.routes.draw do
  resources :stacks, :only => [:index, :show] do
    resource :webhooks, :only => [] do
      post :push, :status
    end
  end
end
