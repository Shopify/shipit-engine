class User < ActiveRecord::Base
  def self.find_or_create_from_github(github_user)
    find_from_github(github_user) || create_from_github!(github_user)
  end

  def self.find_from_github(github_user)
    return unless github_user.id
    where(github_id: github_user.id).first
  end

  def self.create_from_github!(github_user)
    create!(github_user: github_user)
  end

  def self.refresh_shard(shard_index, shards_count)
    where('id % ? = ?', shards_count, shard_index).find_each do |user|
      Resque.enqueue(RefreshGithubUserJob, user_id: user.id)
    end
  end

  def identifiers_for_ping
    {github_id: github_id, name: name, email: email, github_login: login}
  end

  def logged_in?
    true
  end

  def stacks_contributed_to
    return [] unless id
    Commit.where('author_id = :id or committer_id = :id', id: id).uniq.pluck(:stack_id)
  end

  def refresh_from_github!
    update!(github_user: Shipit.github_api.user(login))
  end

  def github_user=(github_user)
    github_user = github_user.rels[:self].get.data unless github_user.name
    assign_attributes(
      github_id: github_user.id,
      name: github_user.name || github_user.login, # Name is not mandatory on GitHub
      email: github_user.email,
      login: github_user.login,
      avatar_url: github_user.rels[:avatar].try(:href),
      api_url: github_user.rels[:self].try(:href),
    )
  end
end
