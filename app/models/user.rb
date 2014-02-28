class User < ActiveRecord::Base

  def self.find_or_create_from_github(github_user)
    find_from_github(github_user) || create_from_github!(github_user)
  end

  def self.find_from_github(github_user)
    return unless github_user.id
    where(github_id: github_user.id).first
  end

  def self.create_from_github!(github_user)
    unless github_user.name
      github_user = github_user.rels[:self].get.data
    end
    create!(
      github_id: github_user.id,
      name: github_user.name,
      email: github_user.email,
      login: github_user.login,
      avatar_url: github_user.avatar_url,
      api_url: github_user.rels[:self].try(:href),
    )
  end

  def avatar_url
    "https://avatars.githubusercontent.com/u/44640"
  end
end
