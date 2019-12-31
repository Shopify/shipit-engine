module Shipit
  class Repository < ApplicationRecord
    OWNER_MAX_SIZE = 39
    private_constant :OWNER_MAX_SIZE

    NAME_MAX_SIZE = 100
    private_constant :NAME_MAX_SIZE

    validates :name, uniqueness: {scope: %i(owner), case_sensitive: false,
                                  message: 'cannot be used more than once'}
    validates :owner, :name, presence: true, ascii_only: true
    validates :owner, format: {with: /\A[a-z0-9_\-\.]+\z/}, length: {maximum: OWNER_MAX_SIZE}
    validates :name, format: {with: /\A[a-z0-9_\-\.]+\z/}, length: {maximum: NAME_MAX_SIZE}

    has_many :stacks, dependent: :destroy

    enum(
      provisioning_behavior: {
        allow_all: 0,
        allow_with_label: 1,
        prevent_with_label: 2,
      },
      _prefix: :provisioning_behavior,
    )

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
      Shipit.github.url("#{owner}/#{name}")
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
