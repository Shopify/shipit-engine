class RegenerateAllWebhooks < ActiveRecord::Migration
  def up
    Stack.find_each do |stack|
      GithubTeardownWebhooksJob.new.perform(stack_id: stack.id, github_repo_name: stack.github_repo_name)
      GithubSetupWebhooksJob.new.perform(stack_id: stack.id)
    end
  end
end
