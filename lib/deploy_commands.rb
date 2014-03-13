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

  def install_dependencies
    deploy_spec.dependencies_steps.map do |command_line|
      Command.new(command_line, env: SSH_ENV, chdir: @deploy.working_directory)
    end
  end

  def deploy(commit)
    env = SSH_ENV.merge('SHA' => commit.sha, 'ENVIRONMENT' => @stack.environment)
    deploy_spec.deploy_steps.map do |command_line|
      Command.new(command_line, env: env, chdir: @deploy.working_directory)
    end
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
  
  def deploy_spec
    @deploy_spec ||= DeploySpec.new(@deploy.working_directory)
  end
end
