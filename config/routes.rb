Shipit::Application.routes.draw do
  resources :stacks, :only => [:index, :show]
end
