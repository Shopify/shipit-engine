module StacksHelper
  def github_change_url(commit)
    commit.pull_request_url || github_commit_url(commit)
  end

  def render_commit_message(commit)
    content_tag(:span, commit.pull_request_title || commit.message, class: 'event-message')
  end

  def render_commit_message_with_link(commit)
    link_to(render_commit_message(commit), github_change_url(commit), target: '_blank')
  end

  def render_commit_id_link(commit)
    if commit.pull_request?
      link_to("##{commit.pull_request_id}", commit.pull_request_url, target: '_blank', class: 'number') +
      "&nbsp;(#{render_raw_commit_id_link(commit)})".html_safe
    else
      render_raw_commit_id_link(commit)
    end
  end

  def render_raw_commit_id_link(commit)
    link_to(commit.short_sha, github_commit_url(commit), target: '_blank', class: 'number')
  end
end
