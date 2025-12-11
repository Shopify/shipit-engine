# frozen_string_literal: true

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
        match_info = raw_git_version.match(/(\d+\.\d+\.\d+)/)
        raise 'git command not found' unless match_info

        Gem::Version.new(match_info[1])
      end
    end

    delegate :git_version, to: :class

    def env
      base_env
    end

    def git(*args)
      kwargs = args.extract_options!
      kwargs[:env] ||= base_env
      Command.new("git", *args, **kwargs)
    end
    ruby2_keywords :git if respond_to?(:ruby2_keywords, true)

    private

    def base_env
      @base_env ||= begin
        env = Shipit.env.merge(
          'GITHUB_DOMAIN' => github.domain,
          'GITHUB_TOKEN' => github.token
        )

        if Shipit.use_git_askpass?
          env['GIT_ASKPASS'] = Shipit::Engine.root.join('lib', 'snippets', 'git-askpass').realpath.to_s
        end

        env
      end
    end

    def github
      Shipit.github
    end
  end
end
