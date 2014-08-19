class UndeployedCommitsWebhookJob < BackgroundJob
  @queue = :default

  self.timeout = 60

  def perform(params)
    return unless stack = Stack.find(params[:stack_id])

    old_undeployed_commits = stack.old_undeployed_commits

    if old_undeployed_commits.present?
      committer_ids = old_undeployed_commits.pluck(:committer_id).uniq
      send_reminder(build_stack_committer_info(stack, committer_ids), stack.reminder_url)
    end
  end

  def build_stack_committer_info(stack, committer_ids)
    stack_committer_info                = {}
    stack_committer_info[:repo_name]    = stack.repo_name
    stack_committer_info[:repo_branch]  = stack.branch
    stack_committer_info[:authors]      = User.all_ids_of_users(committer_ids)
    stack_committer_info.to_json
  end

  def send_reminder(stack_committer_info, reminder_url)
    max_retries = 3

    begin
      response = Net::HTTP.post_form(
        URI.parse(reminder_url),
        {"stack_committer_json" => stack_committer_info }
      )
    rescue Timeout::Error, Errno::ETIMEDOUT
      retry if (max_retries -= 1) > 0
    rescue StandardError
    end

  end
end
