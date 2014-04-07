module StacksHelper

  def render_commit_message(commit)
    url = commit.pull_request_url || github_commit_url(commit.stack.repo_owner, commit.stack.repo_name, commit.sha)
    message = content_tag(:span, commit.pull_request_title || commit.message, class: 'event-message')

    github_id = commit.pull_request? ? "##{commit.pull_request_id}" : commit.short_sha
    identifier = content_tag(:span, "(#{github_id})", class: 'event-number').to_s.html_safe

    link_to(message + identifier, url, target: '_blank')
  end

end
