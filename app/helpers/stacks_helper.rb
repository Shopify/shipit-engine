module StacksHelper

  def github_change_url(commit)
    commit.pull_request_url || github_commit_url(commit)
  end

  def render_commit_message(commit)
    message = content_tag(:span, commit.pull_request_title || commit.message, class: 'event-message')
    link_to(message, github_change_url(commit), target: '_blank')
  end

  def render_commit_id_link(commit)
    github_id = commit.pull_request? ? "##{commit.pull_request_id}" : commit.short_sha
    link_to(github_id, github_change_url(commit), target: '_blank', class: 'number')
  end

end
