module GithubUrlHelper
  DEFAULT_AVATAR = URI.parse('https://avatars.githubusercontent.com/u/583231?')

  def github_url
    "https://github.com"
  end

  def github_avatar(user, options={})
    uri = URI.parse(user.avatar_url) rescue DEFAULT_AVATAR.dup
    attributes = {alt: user.name}
    if options[:size]
      uri.query ||= ''
      uri.query += "&s=#{options[:size]}"
      attributes[:width] = options[:size]
      attributes[:height] = options[:size]
    end

    image_tag(uri.to_s, attributes)
  end

  def github_user_url(user)
    [github_url, user].join("/")
  end

  def github_repo_url(owner, repo)
    [github_user_url(owner), repo].join("/")
  end

  def github_commit_url(commit)
    [github_repo_url(commit.stack.repo_owner, commit.stack.repo_owner), "commit", commit.sha].join("/")
  end

  def github_diff_url(owner, repo, from_sha, to_sha)
    ref = [from_sha, to_sha].join("...")
    [github_repo_url(owner, repo), "compare", ref].join("/")
  end
end
