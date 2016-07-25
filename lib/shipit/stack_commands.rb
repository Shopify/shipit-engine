require 'pathname'
require 'fileutils'

module Shipit
  class StackCommands < Commands
    def initialize(stack)
      @stack = stack
    end

    def fetch
      create_directories
      if Dir.exist?(@stack.git_path)
        git('fetch', 'origin', '--tags', @stack.branch, env: env, chdir: @stack.git_path)
      else
        git_clone(@stack.repo_git_url, @stack.git_path, branch: @stack.branch, env: env, chdir: @stack.deploys_path)
      end
    end

    def fetched?(commit)
      git_dir = File.join(@stack.git_path, '.git')
      if Dir.exist?(git_dir)
        git('rev-parse', '--quiet', '--verify', "#{commit.sha}^{commit}", env: env, chdir: @stack.git_path)
      else
        Command.new('test', '-d', git_dir, env: env, chdir: @stack.deploys_path)
      end
    end

    def fetch_deployed_revision
      with_temporary_working_directory do |dir|
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
      if commit
        @stack.acquire_git_cache_lock do
          fetch.run! unless fetched?(commit).tap(&:run).success?
        end
      end

      Dir.mktmpdir do |dir|
        git('clone', @stack.git_path, @stack.repo_name, chdir: dir).run!
        git('checkout', commit.sha, chdir: dir).run! if commit
        yield Pathname.new(File.join(dir, @stack.repo_name))
      end
    end

    def git_clone(url, path, branch: 'master', **kwargs)
      git('clone', *modern_git_args, '--recursive', '--branch', branch, url, path, **kwargs)
    end

    def modern_git_args
      return [] unless git_version >= Gem::Version.new('1.7.10')
      %w(--single-branch)
    end

    def create_directories
      FileUtils.mkdir_p(@stack.deploys_path)
    end
  end
end
