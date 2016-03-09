namespace :webhook do
  desc "get all the webhooks back in sync"
  task sync_all: [:environment] do
    Shipit::Stack.find_each(&:setup_hooks)
  end
end
