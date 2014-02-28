require "fileutils"

class StackCommands
  SSH_ENV = {'SSH_AUTH_SOCK' => '/u/apps/shipit2/shared/ssh/auth_sock'}
  BUNDLE_WITHOUT = %w(default production development test staging benchmark debug)
  BUNDLE_PATH = File.join(Rails.root, "data", "bundler")

  def initialize(stack)
    @stack = stack
  end

  def bundle_install
    Command.new('bundle', 'install', '--frozen', "--path=#{BUNDLE_PATH}",
                '--retry=2', "--without=#{BUNDLE_WITHOUT.join(':')}", SSH_ENV)
  end

  def deploy(commit)
    env = SSH_ENV.merge('SHA' => commit.sha, 'ENVIRONMENT' => @stack.environment)
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
      Command.new("sh", "-c", "cd #{@stack.git_path} && git fetch", SSH_ENV) # FIXME ugly hax
    else
      git("clone", @stack.repo_git_url, @stack.git_path, SSH_ENV)
    end
  end

  def git(*args)
    Command.new("git", *args)
  end
end
