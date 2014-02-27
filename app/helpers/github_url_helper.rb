module GithubUrlHelper
  def github_url
    "https://github.com"
  end

  def github_repo_url(owner, repo)
    [github_url, owner, repo].join("/")
  end

  def github_commit_url(owner, repo, sha)
    [github_repo_url(owner, repo), "commit", sha].join("/")
  end

  def github_diff_url(owner, repo, from_sha, to_sha)
    ref = [from_sha, to_sha].join("...")
    [github_repo_url(owner, repo), "compare", ref].join("/")
  end
end
