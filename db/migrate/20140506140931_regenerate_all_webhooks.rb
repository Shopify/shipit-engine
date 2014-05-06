class RegenerateAllWebhooks < ActiveRecord::Migration
  def up
    Stack.find_each do |stack|
      GithubTeardownWebhooksJob.new.perform(stack_id: stack.id)
      GithubSetupWebhooksJob.new.perform(stack_id: stack.id)
    end
  end
end
