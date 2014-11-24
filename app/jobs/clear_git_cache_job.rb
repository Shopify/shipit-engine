class ClearGitCacheJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform(params)
    stack = Stack.find(params[:stack_id])
    Command.new('rm', '-rf', stack.git_path, chdir: stack.base_path).run!
  end
end
