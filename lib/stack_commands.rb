require 'fileutils'

class StackCommands < Commands

  def initialize(stack)
    @stack = stack
  end

  def fetch
    create_directories
    if Dir.exists?(@stack.git_path)
      git('fetch', 'origin', @stack.branch, env: env, chdir: @stack.git_path)
    else
      git('clone', '--single-branch', '--branch', @stack.branch, @stack.repo_git_url, @stack.git_path, env: env, chdir: @stack.deploys_path)
    end
  end

  def create_directories
    FileUtils.mkdir_p(@stack.deploys_path)
  end

end
