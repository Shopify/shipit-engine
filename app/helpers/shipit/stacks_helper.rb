# typed: false
module Shipit
  module StacksHelper
    def redeploy_button(deployed_commit)
      commit = UndeployedCommit.new(deployed_commit, index: 0)
      url = new_stack_deploy_path(commit.stack, sha: commit.sha)
      classes = %W(btn btn--primary deploy-action #{commit.state})

      unless commit.stack.deployable?
        classes.push(bypass_safeties? ? 'btn--warning' : 'btn--disabled')
      end

      link_to(t("redeploy_button.caption.#{commit.redeploy_state(bypass_safeties?)}"), url, class: classes)
    end

    def bypass_safeties?
      params[:force].present?
    end

    def deploy_button(commit)
      url = new_stack_deploy_path(commit.stack, sha: commit.sha)
      classes = %W(btn btn--primary deploy-action #{commit.state})
      deploy_state = commit.deploy_state(bypass_safeties?)
      data = {}

      if commit.deploy_disallowed?
        classes.push(bypass_safeties? ? 'btn--warning' : 'btn--disabled')
        if deploy_state == 'blocked'
          data[:tooltip] = t('deploy_button.hint.blocked')
        end
      elsif commit.deploy_discouraged?
        classes.push('btn--warning')
        data[:tooltip] = t('deploy_button.hint.max_commits', maximum: commit.stack.maximum_commits_per_deploy)
      end

      link_to(t("deploy_button.caption.#{deploy_state}"), url, class: classes, data: data)
    end

    def github_change_url(commit)
      if commit.pull_request?
        github_pull_request_url(commit)
      else
        github_commit_url(commit)
      end
    end

    def render_commit_message(pull_request_or_commit)
      message = pull_request_or_commit.title.to_s
      content_tag(:span, emojify(message), class: 'event-message')
    end

    def render_pull_request_title_with_link(pull_request)
      message = render_commit_message(pull_request)
      link_to(message, github_pull_request_url(pull_request), target: '_blank')
    end

    def render_commit_message_with_link(commit)
      message = render_commit_message(commit)
      link_to(message, github_change_url(commit), target: '_blank')
    end

    def render_commit_id_link(commit)
      if commit.pull_request?
        pull_request_link(commit) + "&nbsp;(#{render_raw_commit_id_link(commit)})".html_safe
      else
        render_raw_commit_id_link(commit)
      end
    end

    def pull_request_link(pull_request_or_commit)
      number = if pull_request_or_commit.respond_to?(:pull_request_number)
        pull_request_or_commit.pull_request_number
      else
        pull_request_or_commit.number
      end
      link_to("##{number}", github_pull_request_url(pull_request_or_commit), target: '_blank', class: 'number')
    end

    def render_raw_commit_id_link(commit)
      link_to(commit.short_sha, github_commit_url(commit), target: '_blank', class: 'number')
    end

    def unlock_commit_tooltip(commit)
      if commit.lock_author.present?
        t('commit.unlock_with_author', author: commit.lock_author.name)
      else
        t('commit.unlock')
      end
    end

    def positive_negative_class(value)
      value.to_f >= 0 ? 'positive' : 'negative'
    end
  end
end
