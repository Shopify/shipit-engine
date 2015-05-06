class User < ActiveRecord::Base
  DEFAULT_AVATAR = URI.parse('https://avatars.githubusercontent.com/u/583231?')

  has_many :authored_commits, class_name: :Commit, foreign_key: :author_id, inverse_of: :author
  has_many :commits, foreign_key: :committer_id, inverse_of: :committer
  has_many :tasks

  def self.find_or_create_by_login!(login)
    find_or_create_by!(login: login) do |user|
      user.github_user = Shipster.github_api.user(login)
    end
  end

  def self.find_or_create_from_github(github_user)
    find_from_github(github_user) || create_from_github!(github_user)
  end

  def self.find_from_github(github_user)
    return unless github_user.id
    find_by(github_id: github_user.id)
  end

  def self.create_from_github!(github_user)
    create!(github_user: github_user)
  end

  def self.refresh_shard(shard_index, shards_count)
    where.not(login: nil).where('id % ? = ?', shards_count, shard_index).find_each do |user|
      RefreshGithubUserJob.perform_later(user)
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
    update!(github_user: Shipster.github_api.user(login))
  rescue Octokit::NotFound
    identify_renamed_user!
  end

  def github_user=(github_user)
    return unless github_user
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

  def avatar_uri
    URI.parse(avatar_url)
  rescue URI::InvalidURIError
    DEFAULT_AVATAR.dup
  end

  private

  def identify_renamed_user!
    last_commit = commits.last
    return unless last_commit
    github_author = last_commit.github_commit.author
    update!(github_user: github_author)
  rescue Octokit::NotFound
    false
  end
end
