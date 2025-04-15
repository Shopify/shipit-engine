# frozen_string_literal: true

module Shipit
  class CommandLineUser
    def present?
      false
    end

    def email
      'command_line@example.com'
    end

    def login
      'command_line'
    end

    def name
      'CommandLine'
    end

    def avatar_url
      'https://github.com/images/error/octocat_happy.gif'
    end

    def id; end

    def github_id; end

    def logged_in?
      false
    end

    def authorized?
      Shipit.authentication_disabled?
    end

    def repositories_contributed_to
      []
    end

    def stacks_contributed_to
      []
    end

    def avatar_uri
      User::DEFAULT_AVATAR.dup
    end

    def created_at
      Time.at(0).utc
    end
    alias updated_at created_at

    def read_attribute_for_serialization(attr)
      public_send(attr)
    end

    def github_api
      Shipit.github.api
    end
  end
end
