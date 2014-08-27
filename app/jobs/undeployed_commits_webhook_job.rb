class UndeployedCommitsWebhookJob < BackgroundJob
  queue_as :default

  self.timeout = 60

  def perform(params)
    return unless stack = Stack.find(params[:stack_id])

    old_undeployed_commits = stack.old_undeployed_commits

    if old_undeployed_commits.present?
      committer_ids = old_undeployed_commits.pluck(:committer_id).uniq
      send_reminder(build_stack_committer_json(stack, committer_ids), stack.reminder_url)
    end
  end

  def build_stack_committer_json(stack, committer_ids)
    stack_committer_info = {}
    stack_committer_info[:repo_name] = stack.repo_name
    stack_committer_info[:repo_branch] = stack.branch
    stack_committer_info[:authors] = User.where(id: committer_ids).map(&:identifiers_for_ping)
    stack_committer_info.to_json
  end

  def send_reminder(stack_committer_json, reminder_url)
    max_retries = 3

    begin
      Faraday.post reminder_url, {"stack_committer_json" => stack_committer_json }
    rescue Faraday::Error
      retry if (max_retries -= 1) > 0
    end
  end
end
