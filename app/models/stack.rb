class Stack < ActiveRecord::Base
  STACKS_PATH = File.join(Rails.root, "shared", "stacks")

  has_many :commits
  has_many :deploys

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
