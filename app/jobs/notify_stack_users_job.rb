class NotifyStackUsersJob < BackgroundJob
  @queue = :default

  self.timeout = 60

  def perform(params)
    return unless stack = Stack.find(params[:stack_id])

    old_undeployed_commits = stack.old_undeployed_commits

    if old_undeployed_commits.present?
      committer_ids = old_undeployed_commits.pluck(:committer_id).uniq
      json_output = escaped_json(stack, committer_ids)
      notify(json_output, stack.reminder_url)
    end
  end

  def escaped_json(stack, committer_ids)
    output = {}
    output[:repo_name] = stack.repo_name
    output[:repo_branch] = stack.branch
    output[:authors] = User.all_ids_of_users(committer_ids)
    URI.escape(output.to_json)
  end

  def notify(json_output, url)
    `curl --connect-timeout 5 \
          --max-time 10 \
          --retry 3 \
          --retry-delay 5 \
          --retry-max-time 30 \
          -d "json_output=#{json_output}" \
          #{url}`
  end
end
