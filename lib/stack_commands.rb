require 'fileutils'

class StackCommands < Commands

  def initialize(stack)
    @stack = stack
  end

  def fetch
    create_directories
    if Dir.exists?(@stack.git_path)
      git('fetch', 'origin', '--tags', @stack.branch, env: env, chdir: @stack.git_path)
    else
      git('clone', *modern_git_args, '--branch', @stack.branch, @stack.repo_git_url, @stack.git_path, env: env, chdir: @stack.deploys_path)
    end
  end

  def modern_git_args
    return [] unless git_version >= Gem::Version.new('1.7.10')
    %w(--single-branch)
  end

  def create_directories
    FileUtils.mkdir_p(@stack.deploys_path)
  end

end
