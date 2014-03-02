require "fileutils"
require "etc"

class DeployCommands
  SSH_ENV = {
    'SSH_AUTH_SOCK' => '/u/apps/shipit2/shared/ssh/auth_sock',
    'HOME' => Etc.getpwuid(Process::Sys.getuid).dir
  }
  BUNDLE_WITHOUT = %w(default production development test staging benchmark debug)
  BUNDLE_PATH = File.join(Rails.root, "data", "bundler")

  def initialize(deploy)
    @deploy = deploy
    @stack = deploy.stack
  end

  def bundle_install
    Command.new('bundle', 'install', '--frozen', "--path=#{BUNDLE_PATH}",
                '--retry=2', "--without=#{BUNDLE_WITHOUT.join(':')}", env: SSH_ENV, chdir: @deploy.working_directory)
  end

  def deploy(commit)
    env = SSH_ENV.merge('SHA' => commit.sha, 'ENVIRONMENT' => @stack.environment)
    Command.new('bundle', 'exec', 'cap', @stack.environment, 'deploy', env: env, chdir: @deploy.working_directory)
  end

  def checkout(commit)
    git("checkout", "-q", commit.sha, chdir: @deploy.working_directory)
  end

  def clone
    git("clone", "--local", @stack.git_path, @deploy.working_directory, chdir: @stack.deploys_path)
  end

  def create_directories
    FileUtils.mkdir_p(@stack.deploys_path)
  end

  def fetch
    create_directories
    if Dir.exists?(@stack.git_path)
      git("fetch", env: SSH_ENV, chdir: @stack.git_path)
    else
      git("clone", @stack.repo_git_url, @stack.git_path, env: SSH_ENV, chdir: @stack.deploys_path)
    end
  end

  def git(*args)
    Command.new("git", *args)
  end
end
