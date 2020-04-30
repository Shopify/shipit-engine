# frozen_string_literal: true
module Shipit
  class User < ActiveRecord::Base
    DEFAULT_AVATAR = URI.parse('https://avatars.githubusercontent.com/u/583231?')

    has_many :memberships
    has_many :teams, through: :memberships
    has_many :authored_commits, class_name: :Commit, foreign_key: :author_id, inverse_of: :author
    has_many :commits, foreign_key: :committer_id, inverse_of: :committer
    has_many :tasks

    validates :name, presence: true

    attr_encrypted :github_access_token, key: Shipit.user_access_tokens_key

    def self.find_or_create_by_login!(login)
      find_or_create_by!(login: login) do |user|
        user.github_user = Shipit.github.api.user(login)
      end
    end

    def self.find_or_create_committer_from_github_commit(github_commit)
      find_or_create_from_github(github_commit.committer.presence || github_commit.commit.committer.presence)
    end

    def self.find_or_create_author_from_github_commit(github_commit)
      if (match_info = github_commit.commit.message.match(/^#{PullRequest::MERGE_REQUEST_FIELD}: ([\w\-\.]+)$/))
        begin
          return find_or_create_by_login!(match_info[1])
        rescue Octokit::NotFound
          # Corner case where the merge-requested-by user cannot be found (renamed/deleted).
          # In this case we carry on and search for the commit author
        end
      end
      find_or_create_from_github(github_commit.author.presence || github_commit.commit.author.presence)
    end

    def self.find_or_create_from_github(github_user)
      find_from_github(github_user) || create_from_github(github_user)
    end

    def self.find_from_github(github_user)
      return unless github_user.id
      find_by(github_id: github_user.id)
    end

    def self.create_from_github(github_user)
      create(github_user: github_user)
    end

    def self.refresh_shard(shard_index, shards_count)
      where.not(login: nil).where('id % ? = ?', shards_count, shard_index).find_each do |user|
        RefreshGithubUserJob.perform_later(user)
      end
    end

    alias_method :original_github_access_token, :github_access_token
    def github_access_token
      original_github_access_token
    rescue OpenSSL::Cipher::CipherError
      update_columns(encrypted_github_access_token: nil, encrypted_github_access_token_iv: nil)
      nil
    end

    def github_api
      return Shipit.github.api unless github_access_token

      @github_api ||= Shipit.github.new_client(access_token: github_access_token)
    end

    def identifiers_for_ping
      { github_id: github_id, name: name, email: email, github_login: login }
    end

    def logged_in?
      true
    end

    def authorized?
      @authorized ||= Shipit.github_teams.empty? || teams.where(id: Shipit.github_teams.map(&:id)).exists?
    end

    def stacks_contributed_to
      return [] unless id
      Commit.where('author_id = :id or committer_id = :id', id: id).distinct.pluck(:stack_id)
    end

    def refresh_from_github!
      update!(github_user: Shipit.github.api.user(github_id))
    rescue Octokit::NotFound
      identify_renamed_user!
    end

    def github_user=(github_user)
      return unless github_user

      if github_user.name.nil? && github_user.rels && github_user.rels[:self]
        github_user = github_user.rels[:self].get.data
      end

      assign_attributes(
        github_id: github_user.id,
        name: github_user.name || github_user.login, # Name is not mandatory on GitHub
        email: appropriate_email_for(github_user),
        login: github_user.login,
        avatar_url: github_user.avatar_url,
        api_url: github_user.url,
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

    def email_valid_and_preferred?(email_address)
      org_domains = Shipit.preferred_org_emails
      return true if org_domains.blank?
      return false if email_address.blank?

      org_domains.any? { |domain| email_address.end_with?("@#{domain}") }
    end

    def appropriate_email_for(github_user)
      return github_user.email if email_valid_and_preferred?(github_user.email)

      begin
        github_api.emails
          .sort_by { |e| e.primary ? 0 : 1 }
          .map(&:email)
          .find { |e| email_valid_and_preferred?(e) }
      rescue Octokit::NotFound, Octokit::Forbidden, Octokit::Unauthorized
        # If the user hasn't agreed to the necessary permission, we can't access their private emails.
        Rails.logger.warn("Failed to retrieve emails for user '#{github_user.name || github_user.login}'")
        nil
      end
    end
  end
end
