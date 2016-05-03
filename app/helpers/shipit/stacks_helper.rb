module Shipit
  module StacksHelper
    COMMIT_TITLE_LENGTH = 79

    def redeploy_button(commit)
      url = new_stack_deploy_path(commit.stack, sha: commit.sha)
      classes = %W(btn btn--primary deploy-action #{commit.state})

      unless commit.stack.deployable?
        classes.push(bypass_safeties? ? 'btn--warning' : 'btn--disabled')
      end

      link_to(t("deploy_button.caption.#{commit.redeploy_state(bypass_safeties?)}"), url, class: classes)
    end

    def bypass_safeties?
      params[:force].present?
    end

    def deploy_button(commit)
      url = new_stack_deploy_path(commit.stack, sha: commit.sha)
      classes = %W(btn btn--primary deploy-action #{commit.state})
      data = {}
      if commit.deploy_disallowed?
        classes.push(bypass_safeties? ? 'btn--warning' : 'btn--disabled')
      elsif commit.deploy_discouraged?
        classes.push('btn--warning')
        data[:tooltip] = t('deploy_button.hint.max_commits', maximum: commit.stack.maximum_commits_per_deploy)
      end

      link_to(t("deploy_button.caption.#{commit.deploy_state(bypass_safeties?)}"), url, class: classes, data: data)
    end

    def github_change_url(commit)
      commit.pull_request_url || github_commit_url(commit)
    end

    def render_commit_message(commit)
      message = commit.pull_request_title || commit.message
      content_tag(:span, emojify(message.truncate(COMMIT_TITLE_LENGTH)), class: 'event-message')
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
      link_to("##{commit.pull_request_number}", commit.pull_request_url, target: '_blank', class: 'number')
    end

    def render_raw_commit_id_link(commit)
      link_to(commit.short_sha, github_commit_url(commit), target: '_blank', class: 'number')
    end
  end
end
