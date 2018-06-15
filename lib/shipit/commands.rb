module Shipit
  class Commands
    class << self
      def for(model)
        "#{model.class.name}Commands".constantize.new(model)
      end

      def git_version
        @git_version ||= parse_git_version(`git --version`)
      end

      def parse_git_version(raw_git_version)
        raw_git_version =~ /(\d+\.\d+\.\d+)/
        raise 'git command not found' unless $1
        Gem::Version.new($1)
      end
    end

    delegate :git_version, to: :class

    def env
      @env ||= Shipit.env.merge(
        'GITHUB_DOMAIN' => Shipit.github.domain,
        'GITHUB_TOKEN' => Shipit.github.token,
        'GIT_ASKPASS' => Shipit::Engine.root.join('lib', 'snippets', 'git-askpass').realpath.to_s,
      )
    end

    def git(*args)
      Command.new("git", *args)
    end
  end
end
