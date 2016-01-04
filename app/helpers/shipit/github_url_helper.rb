module Shipit
  module GithubUrlHelper
    def github_avatar(user, options = {})
      uri = user.avatar_uri
      attributes = options.slice(:class).merge(alt: user.try!(:name))
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

    def github_user_url(user, *args)
      [Shipit.github_url, user, *args].join('/')
    end

    def render_github_user(user)
      link_to(github_user_url(user.login), class: 'user main-user') do
        github_avatar(user, size: 20) + user.name
      end
    end

    def github_repo_url(owner, repo, *args)
      github_user_url(owner, repo, *args)
    end

    def github_commit_url(commit)
      github_repo_url(commit.stack.repo_owner, commit.stack.repo_name, 'commit', commit.sha)
    end

    def github_diff_url(owner, repo, from_sha, to_sha)
      github_repo_url(owner, repo, 'compare', "#{from_sha}...#{to_sha}")
    end

    def link_to_github_deploy(deploy)
      url = github_commit_range_url(deploy.stack, *deploy.commit_range)
      text = deploy.commit_range.map(&:short_sha).join('...')
      link_to(text, url, class: 'number')
    end
  end
end
