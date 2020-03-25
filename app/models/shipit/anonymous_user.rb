# typed: true
module Shipit
  class AnonymousUser
    def present?
      false
    end

    def email
      'anonymous@example.com'
    end

    def login
      'anonymous'
    end

    def name
      'Anonymous'
    end

    def avatar_url
      'https://github.com/images/error/octocat_happy.gif'
    end

    def id
    end

    def github_id
    end

    def logged_in?
      false
    end

    def authorized?
      Shipit.authentication_disabled?
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
    alias_method :updated_at, :created_at

    def read_attribute_for_serialization(attr)
      public_send(attr)
    end

    def github_api
      Shipit.github.api
    end
  end
end
