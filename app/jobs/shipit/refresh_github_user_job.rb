# frozen_string_literal: true
module Shipit
  class RefreshGithubUserJob < BackgroundJob
    queue_as :default

    def perform(user)
      user.refresh_from_github!
    end
  end
end
