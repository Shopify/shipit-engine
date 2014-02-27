class Stack < ActiveRecord::Base
  STACKS_PATH = File.join(Rails.root, "shared", "stacks")

  has_many :commits
  has_many :deploys

  def remote_repo_http_url
    "https://github.com/#{repo_owner}/#{repo_name}"
  end

  def remote_repo_git_url
    "git@github.com:#{repo_owner}/#{repo_name}.git"
  end

  def local_base_path
    File.join(STACKS_PATH, repo_owner, repo_name, environment)
  end

  def local_deploys_path
    File.join(local_base_path, "deploys")
  end

  def local_git_path
    File.join(local_base_path, "git")
  end
end
