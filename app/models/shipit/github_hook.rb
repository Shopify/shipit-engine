# typed: false
module Shipit
  class GithubHook < ActiveRecord::Base
    # TODO: app-migration, delete class
    belongs_to :stack, required: false # Required for fixtures

    before_destroy :teardown!

    delegate :github_repo_name, to: :stack

    def teardown!
      destroy_hook! if already_setup?
      true
    end

    def event=(event)
      super(event.to_s)
    end

    def already_setup?
      github_id?
    end

    def api
      Shipit.legacy_github_api
    end

    class Repo < GithubHook
      belongs_to :stack, required: true

      private

      def destroy_hook!
        api.remove_hook(github_repo_name, github_id)
      rescue Octokit::NotFound
      end
    end

    class Organization < GithubHook
      validates :organization, presence: true

      private

      def destroy_hook!
        api.remove_org_hook(organization, github_id)
      rescue Octokit::NotFound
      end
    end
  end
end
