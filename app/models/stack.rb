class Stack < ActiveRecord::Base
  STACKS_PATH = File.join(Rails.root, "data", "stacks")

  has_many :commits
  has_many :deploys

  def trigger_deploy(until_commit)
    since_commit = last_deployed_commit

    deploy = deploys.create(
      until_commit: until_commit,
      since_commit: since_commit
    )
    if deploy.persisted?
      Resque.enqueue(DeployJob, deploy_id: id)
    end
    deploy
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

  def to_param
    [repo_owner, repo_name, environment].join('/')
  end

  def self.from_param(param)
    repo_owner, repo_name, environment = param.split('/')
    where(
      :repo_owner  => repo_owner,
      :repo_name   => repo_name,
      :environment => environment
    ).first!
  end
end
