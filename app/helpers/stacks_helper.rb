module StacksHelper

  def render_commit_message(commit)
    url = commit.pull_request_url || github_commit_url(commit.stack.repo_owner, commit.stack.repo_name, commit.sha)
    message = commit.pull_request_title || commit.message
    github_id = commit.pull_request? ? "##{commit.pull_request_id}" : commit.short_sha
    message += ' ' + content_tag(:span, "(#{github_id})", class: 'event-number')
    link_to(message.html_safe, url)
  end

end
