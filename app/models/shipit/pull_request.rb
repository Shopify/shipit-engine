# frozen_string_literal: true

module Shipit
  class PullRequest < Record
    include DeferredTouch

    belongs_to :stack
    belongs_to :user

    has_many :pull_request_assignments
    has_many :assignees, class_name: :User, through: :pull_request_assignments, source: :user

    has_many :pull_request_labels
    has_many :labels, through: :pull_request_labels

    def self.from_github(github_pull_request)
      new(attributes_from_github(github_pull_request))
    end

    def self.attributes_from_github(github_pull_request)
      {
        github_id: github_pull_request.id,
        number: github_pull_request.number,
        api_url: github_pull_request.url,
        title: github_pull_request.title,
        state: github_pull_request.state,
        additions: github_pull_request.additions,
        deletions: github_pull_request.deletions,
        user: User.find_or_create_by_login!(github_pull_request.user.login),
        assignees: github_pull_request.assignees.map { |github_user| User.find_or_create_by_login!(github_user.login) },
        labels: github_pull_request.labels.map { |github_label| Label.find_or_create_from_github!(github_label) },
      }
    end
  end
end
