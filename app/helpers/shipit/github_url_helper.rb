module Shipit
  module GithubUrlHelper
    private

    def github_avatar(user, options = {})
      uri = user.avatar_uri
      attributes = options.slice(:class).merge(alt: user&.name)
      if options[:size]
        uri.query ||= ''
        uri.query += "&s=#{options[:size]}"
        attributes[:width] = options[:size]
        attributes[:height] = options[:size]
      end

      image_tag(uri.to_s, attributes)
    end

    def github_commit_range_url(stack, since_commit, until_commit)
      github_repo_url(stack.repo_owner, stack.repo_name, 'compare', "#{since_commit.sha}...#{until_commit.sha}")
    end
    module_function :github_commit_range_url

    def github_user_url(user, *args)
      Shipit.github.url(user, *args)
    end
    module_function :github_user_url

    def render_github_user(user)
      link_to(github_user_url(user.login), class: 'user main-user') do
        github_avatar(user, size: 20) + user.name
      end
    end

    def github_repo_url(owner, repo, *args)
      github_user_url(owner, repo, *args)
    end
    module_function :github_repo_url

    def github_commit_url(commit)
      github_repo_url(commit.stack.repo_owner, commit.stack.repo_name, 'commit', commit.sha)
    end

    def github_pull_request_url(pull_request_or_commit)
      stack = pull_request_or_commit.stack
      number = if pull_request_or_commit.respond_to?(:pull_request_number)
        pull_request_or_commit.pull_request_number
      else
        pull_request_or_commit.number
      end
      github_repo_url(stack.repo_owner, stack.repo_name, 'pull', number)
    end

    def stack_github_url(stack)
      if stack.review_request
        github_pull_request_url(stack.review_request)
      else
        github_repo_url(stack.repo_owner, stack.repo_name)
      end
    end

    def link_to_github_deploy(deploy)
      url = github_commit_range_url(deploy.stack, *deploy.commit_range)
      text = deploy.commit_range.map(&:short_sha).join('...')
      link_to(text, url, class: 'number')
    end
  end
end
