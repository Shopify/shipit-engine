class ClearGitCacheJob < BackgroundJob
  queue_as :default

  extend BackgroundJob::StackExclusive

  def perform(stack)
    Command.new('rm', '-rf', stack.git_path, chdir: stack.base_path).run!
  end
end
