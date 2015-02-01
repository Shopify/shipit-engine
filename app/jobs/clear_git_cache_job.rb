class ClearGitCacheJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform
    Command.new('rm', '-rf', stack.git_path, chdir: stack.base_path).run!
  end

  def stack
    @stack ||= Stack.find(params[:stack_id])
  end
end
