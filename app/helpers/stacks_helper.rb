module StacksHelper

  def render_commit_message(commit)
    url = commit.pull_request_url || github_commit_url(commit)
    message = content_tag(:span, commit.pull_request_title || commit.message, class: 'event-message')

    link_to(message, url, target: '_blank')
  end

  def render_commit_id_link(commit)
    url = commit.pull_request_url || github_commit_url(commit)
    github_id = commit.pull_request? ? "##{commit.pull_request_id}" : commit.short_sha
    link_to(github_id, url, target: '_blank', class: 'number')
  end

end
