require "fileutils"

class StackCommands

  def initialize(stack)
    @stack = stack
  end

  def bundle_install
    Command.new('bundle', 'install')
  end

  def deploy(commit)
    env = {'SHA' => commit.sha, 'ENVIRONMENT' => @stack.environment, 'SSH_AUTH_SOCK' => '/u/apps/shipit2/shared/ssh/auth_sock'}
    Command.new('bundle', 'exec', 'cap', @stack.environment, 'deploy', env)
  end

  def checkout(commit)
    git("checkout", "-q", commit.sha)
  end

  def clone(deploy)
    git("clone", "--local", @stack.git_path, deploy.working_directory)
  end

  def create_directories
    FileUtils.mkdir_p(@stack.deploys_path)
  end

  def fetch
    create_directories
    if Dir.exists?(@stack.git_path)
      git("fetch", @stack.git_path)
    else
      git("clone", @stack.repo_git_url, @stack.git_path)
    end
  end

  def git(*args)
    Command.new("git", *args)
  end
end
