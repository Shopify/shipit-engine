namespace :webhook do
  desc "get all the webhooks back in sync"
  task sync_all: [:environment] do
    Stack.all.each do |stack|
      GithubSetupWebhooksJob.new(stack_id: stack.id, github_repo_name: stack.github_repo_name).perform
    end
  end
end
