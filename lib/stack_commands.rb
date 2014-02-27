require "fileutils"

class StackCommands
  def initialize(stack)
    @stack = stack
  end

  def deploy(commit)
    system(*%W(echo deploying #{commit.sha}))
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
    puts "RUN: #{args.join(' ')}"
    system("git", *args)
  end
end
