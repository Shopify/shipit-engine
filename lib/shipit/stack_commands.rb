# frozen_string_literal: true

# rubocop:disable Lint/MissingSuper
require 'pathname'
require 'fileutils'

module Shipit
  class StackCommands < Commands
    def initialize(stack)
      @stack = stack
    end

    def env
      super.merge(@stack.env)
    end

    def fetch_commit(commit)
      create_directories
      if valid_git_repository?(@stack.git_path)
        git('fetch', 'origin', '--quiet', '--tags', commit.sha, env: env, chdir: @stack.git_path)
      else
        @stack.clear_git_cache!
        git_clone(@stack.repo_git_url, @stack.git_path, branch: @stack.branch, env: env, chdir: @stack.deploys_path)
      end
    end

    def fetch
      create_directories
      if valid_git_repository?(@stack.git_path)
        git('fetch', 'origin', '--quiet', '--tags', @stack.branch, env: env, chdir: @stack.git_path)
      else
        @stack.clear_git_cache!
        git_clone(@stack.repo_git_url, @stack.git_path, branch: @stack.branch, env: env, chdir: @stack.deploys_path)
      end
    end

    def fetched?(commit)
      if valid_git_repository?(@stack.git_path)
        git('rev-parse', '--quiet', '--verify', "#{commit.sha}^{commit}", env: env, chdir: @stack.git_path)
      else
        # When the stack's git cache is not valid, the commit is
        # NOT fetched. To keep the interface of this method
        # consistent, we must return a Shipit::Command whose #success?
        # method returns false - has a non-zero exit status. We utilize
        # the POSIX 'test' command with no arguments which should
        # always have an exit status of 1.
        Command.new('test', env: env, chdir: @stack.deploys_path)
      end
    end

    def fetch_deployed_revision
      with_temporary_working_directory(commit: @stack.commits.reachable.last) do |dir|
        spec = DeploySpec::FileSystem.new(dir, @stack.environment)
        outputs = spec.fetch_deployed_revision_steps!.map do |command_line|
          Command.new(command_line, env: env, chdir: dir).run
        end
        outputs.find(&:present?).try(:strip)
      end
    end

    def build_cacheable_deploy_spec
      with_temporary_working_directory do |dir|
        DeploySpec::FileSystem.new(dir, @stack.environment).cacheable
      end
    end

    def with_temporary_working_directory(commit: nil)
      commit ||= @stack.last_deployed_commit.presence || @stack.commits.reachable.last

      if !commit || !fetched?(commit).tap(&:run).success?
        @stack.acquire_git_cache_lock do
          unless fetched?(commit).tap(&:run).success?
            fetch.run!
          end
        end
      end

      Dir.mktmpdir do |dir|
        git(
          'clone', @stack.git_path, @stack.repo_name,
          '--recursive', '--origin', 'cache',
          chdir: dir
        ).run!

        git_dir = File.join(dir, @stack.repo_name)
        git(
          '-c',
          'advice.detachedHead=false',
          'checkout',
          '--quiet',
          commit.sha,
          chdir: git_dir
        ).run! if commit
        yield Pathname.new(git_dir)
      end
    end

    def valid_git_repository?(path)
      path.exist? &&
        !path.empty? &&
        git_cmd_succeeds?(path)
    end

    def git_cmd_succeeds?(path)
      git("rev-parse", "--git-dir", chdir: path)
        .tap(&:run)
        .success?
    end

    def git_clone(url, path, branch: 'main', **kwargs)
      git('clone', '--quiet', *modern_git_args, '--recursive', '--branch', branch, url, path, **kwargs)
    end

    def modern_git_args
      return [] unless git_version >= Gem::Version.new('1.7.10')
      %w(--single-branch)
    end

    def create_directories
      FileUtils.mkdir_p(@stack.deploys_path)
    end

    private

    def github
      Shipit.github(organization: @stack.repository.owner)
    end
  end
end
