module Shipit
  class UnknownRepository
    def owner
      "unknown-owner"
    end

    def name
      "unknown-name"
    end

    def stacks
      Stack.none
    end

    def http_url
      Shipit.github.url("#{owner}/#{name}")
    end

    def git_url
      "https://#{Shipit.github.domain}/#{owner}/#{name}.git"
    end
  end
end
