class GitMirrorUpdateJob < BackgroundJob
  @queue = :default

  extend BackgroundJob::StackExclusive

  def perform(params)
    stack = Stack.find(params[:stack_id])
    path  = stack.git_mirror_path

    if path.exist?
      Dir.chdir(path) do
        run(%w(git remote update --prune))
      end
    else
      run(%w(git clone --mirror) + ["git@github.com:#{stack.github_repo_name}.git", path.to_s])
    end
  end

  def run(command)
    Rails.logger.info "Executing command: #{command.inspect}"
    system(*command)
    raise "Command failed: #{command.inspect}" unless $?.success?
  end
end
