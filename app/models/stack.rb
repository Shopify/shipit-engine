class Stack < ActiveRecord::Base
  STACKS_PATH = File.join(Rails.root, "shared", "stacks")

  has_many :commits
  has_many :deploys

  def trigger_deploy(until_commit)
    since_commit = last_deployed_commit

    deploys.create(
      until_commit: until_commit,
      since_commit: since_commit
    )
  end

  def last_deployed_commit
    if last_deploy = deploys.last
      last_deploy.until_commit
    else
      commits.first
    end
  end

  def repo_http_url
    "https://github.com/#{repo_owner}/#{repo_name}"
  end

  def repo_git_url
    "git@github.com:#{repo_owner}/#{repo_name}.git"
  end

  def base_path
    File.join(STACKS_PATH, repo_owner, repo_name, environment)
  end

  def deploys_path
    File.join(base_path, "deploys")
  end

  def git_path
    File.join(base_path, "git")
  end

  def github_repo_name
    return [repo_owner, repo_name].join('/')
  end

  def github_repo
    Shipit.github_api.repo(github_repo_name)
  end

  def git_mirror_path
    Rails.root + 'data' + 'mirror' + repo_name
  end
end
