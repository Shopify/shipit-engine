module Shipit
  module StacksHelper
    COMMIT_TITLE_LENGTH = 79

    def redeploy_button(commit)
      url = new_stack_deploy_path(@stack, sha: commit.sha)
      classes = %W(btn btn--primary deploy-action #{commit.state})

      unless commit.stack.deployable?
        classes.push(ignore_lock? ? 'btn--warning' : 'btn--disabled')
      end

      caption = 'Redeploy'
      caption = 'Locked' if commit.stack.locked? && !ignore_lock?
      caption = 'Deploy in progress...' if commit.stack.active_task?

      link_to(caption, url, class: classes)
    end

    def ignore_lock?
      params[:force].present?
    end

    def deploy_button(commit)
      url = new_stack_deploy_path(@stack, sha: commit.sha)
      classes = %W(btn btn--primary deploy-action #{commit.state})
      if deploy_button_disabled?(commit)
        classes.push(params[:force].present? ? 'btn--warning' : 'btn--disabled')
      end

      link_to(deploy_button_caption(commit), url, class: classes)
    end

    def github_change_url(commit)
      commit.pull_request_url || github_commit_url(commit)
    end

    def render_commit_message(commit)
      message = commit.pull_request_title || commit.message
      content_tag(:span, message.truncate(COMMIT_TITLE_LENGTH), class: 'event-message')
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
      !commit.deployable? || !commit.stack.deployable?
    end

    def deploy_button_caption(commit)
      state = commit.status.state
      state = 'locked' if commit.stack.locked? && !ignore_lock?
      if commit.deployable?
        state = commit.stack.active_task? ? 'deploying' : 'enabled'
      end
      t("deploy_button.caption.#{state}")
    end
  end
end
