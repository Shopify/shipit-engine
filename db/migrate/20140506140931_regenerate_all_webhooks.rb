class RegenerateAllWebhooks < ActiveRecord::Migration
  def up
    Stack.find_each do |stack|
      GithubTeardownWebhooksJob.new(stack_id: stack.id, github_repo_name: stack.github_repo_name).perform
      GithubSetupWebhooksJob.new(stack_id: stack.id).perform
    end
  end
end
