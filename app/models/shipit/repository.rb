# frozen_string_literal: true
module Shipit
  class NullRepository
    def id
      nil
    end

    def stacks
      Shipit::Stack.none
    end

    def review_stacks
      Shipit::ReviewStack.none
    end

    def review_stacks_enabled
      false
    end

    def provisioning_behavior_allow_all?
      false
    end

    def provisioning_behavior_allow_with_label?
      false
    end

    def provisioning_behavior_prevent_with_label?
      false
    end
  end

  class Repository < ApplicationRecord
    OWNER_MAX_SIZE = 39
    private_constant :OWNER_MAX_SIZE

    NAME_MAX_SIZE = 100
    private_constant :NAME_MAX_SIZE

    validates :name, uniqueness: { scope: %i(owner), case_sensitive: false,
                                   message: 'cannot be used more than once' }
    validates :owner, :name, presence: true, ascii_only: true
    validates :owner, format: { with: /\A[a-z0-9_\-\.]+\z/ }, length: { maximum: OWNER_MAX_SIZE }
    validates :name, format: { with: /\A[a-z0-9_\-\.]+\z/ }, length: { maximum: NAME_MAX_SIZE }

    has_many :stacks, dependent: :destroy
    has_many :review_stacks, dependent: :destroy

    PROVISIONING_BEHAVIORS = %w(allow_all allow_with_label prevent_with_label).freeze
    enum provisioning_behavior: PROVISIONING_BEHAVIORS.zip(PROVISIONING_BEHAVIORS).to_h, _prefix: :provisioning_behavior

    def self.from_github_repo_name(github_repo_name)
      repo_owner, repo_name = github_repo_name.downcase.split('/')
      find_by(owner: repo_owner, name: repo_name)
    end

    def name=(n)
      super(n&.downcase)
    end

    def owner=(o)
      super(o&.downcase)
    end

    def github_repo_name
      [owner, name].join('/')
    end

    def http_url
      Shipit.github.url(full_name)
    end

    def full_name
      "#{owner}/#{name}"
    end

    def git_url
      "https://#{Shipit.github.domain}/#{owner}/#{name}.git"
    end

    def schedule_for_destroy!
      DestroyRepositoryJob.perform_later(self)
    end

    def to_param
      github_repo_name
    end

    def self.from_param!(param)
      repo_owner, repo_name = param.split('/')
      where(
        owner: repo_owner.downcase,
        name: repo_name.downcase,
      ).first!
    end
  end
end
