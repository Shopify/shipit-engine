# frozen_string_literal: true

# rubocop:disable Lint/MissingCopEnableDirective, Lint/MissingSuper
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
        git('fetch', 'origin', *quiet_git_arg, '--tags', '--force', commit.sha, env:, chdir: @stack.git_path)
      else
        @stack.clear_git_cache!
        git_clone(@stack.repo_git_url, @stack.git_path, branch: @stack.branch, env:, chdir: @stack.deploys_path)
      end
    end

    def fetch
      create_directories
      if valid_git_repository?(@stack.git_path)
        git('fetch', 'origin', *quiet_git_arg, '--tags', '--force', @stack.branch, env:, chdir: @stack.git_path)
      else
        @stack.clear_git_cache!
        git_clone(@stack.repo_git_url, @stack.git_path, branch: @stack.branch, env:, chdir: @stack.deploys_path)
      end
    end

    def fetched?(commit)
      if valid_git_repository?(@stack.git_path)
        git('rev-parse', *quiet_git_arg, '--verify', "#{commit.sha}^{commit}", env:, chdir: @stack.git_path)
      else
        # When the stack's git cache is not valid, the commit is
        # NOT fetched. To keep the interface of this method
        # consistent, we must return a Shipit::Command whose #success?
        # method returns false - has a non-zero exit status. We utilize
        # the POSIX 'test' command with no arguments which should
        # always have an exit status of 1.
        Command.new('test', env:, chdir: @stack.deploys_path)
      end
    end

    def fetch_deployed_revision
      with_temporary_working_directory(commit: @stack.commits.reachable.last) do |dir|
        spec = DeploySpec::FileSystem.new(dir, @stack)
        outputs = spec.fetch_deployed_revision_steps!.map do |command_line|
          Command.new(command_line, env:, chdir: dir).run
        end
        outputs.find(&:present?).try(:strip)
      end
    end

    def build_cacheable_deploy_spec
      with_temporary_working_directory(recursive: false) do |dir|
        DeploySpec::FileSystem.new(dir, @stack).cacheable
      end
    end

    def with_temporary_working_directory(commit: nil, recursive: true)
      commit ||= @stack.last_deployed_commit.presence || @stack.commits.reachable.last

      if !commit || !fetched?(commit).tap(&:run).success?
        @stack.acquire_git_cache_lock do
          fetch.run! unless fetched?(commit).tap(&:run).success?
        end
      end

      git_args = []
      git_args << '--recursive' if recursive
      Dir.mktmpdir do |dir|
        git(
          'clone', @stack.git_path, @stack.repo_name,
          *git_args, '--origin', 'cache',
          chdir: dir
        ).run!

        git_dir = File.join(dir, @stack.repo_name)
        if commit
          git(
            '-c',
            'advice.detachedHead=false',
            'checkout',
            *quiet_git_arg,
            commit.sha,
            chdir: git_dir
          ).run!
        end
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
      git('clone', *quiet_git_arg, *modern_git_args, '--recursive', '--branch', branch, url, path, **kwargs)
    end

    def modern_git_args
      return [] unless git_version >= Gem::Version.new('1.7.10')

      %w[--single-branch]
    end

    def create_directories
      FileUtils.mkdir_p(@stack.deploys_path)
    end

    def quiet_git_arg
      Shipit.git_progress_output ? [] : ['--quiet']
    end

    private

    def github
      Shipit.github(organization: @stack.repository.owner)
    end
  end
end
