Shipit::Application.routes.draw do
  resource :stacks, :only => [:index, :show]
end
