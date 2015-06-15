module StacksHelper
  DISABLED_BUTTON = %w(btn--disabled disabled).freeze

  def deploy_button(commit)
    url = new_stack_deploy_path(@stack, sha: commit.sha)
    classes = %W(btn btn--primary deploy-action #{commit.state})
    classes << 'btn--disabled' << 'disabled' if deploy_button_disabled?(commit)

    link_to(deploy_button_caption(commit), url, class: classes)
  end

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
      pull_request_link(commit) + "&nbsp;(#{render_raw_commit_id_link(commit)})".html_safe
    else
      render_raw_commit_id_link(commit)
    end
  end

  def pull_request_link(commit)
    link_to("##{commit.pull_request_id}", commit.pull_request_url, target: '_blank', class: 'number')
  end

  def render_raw_commit_id_link(commit)
    link_to(commit.short_sha, github_commit_url(commit), target: '_blank', class: 'number')
  end

  private

  def deploy_button_disabled?(commit)
    !commit.deployable? || commit.stack.locked?
  end

  def deploy_button_caption(commit)
    return 'Locked' if commit.stack.locked?

    if commit.deployable?
      return 'Deploy in progress...' if commit.stack.deploying?
      return 'Deploy'
    end

    return 'CI Pending...' if commit.pending?
    return 'CI Failure' if commit.failure?
    return 'CI Error' if commit.error?
    'Not Run'
  end
end
