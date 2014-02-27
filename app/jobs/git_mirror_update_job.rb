class GitMirrorUpdateJob
  def perform(params)
    stack = Stack.find(params[:stack_id])
    path  = stack.git_mirror_path

    Dir.chdir(path) do
      run(%w(git remote update --prune))
    end
  end

  def run(command)
    system(*command)
    raise "Command failed: #{command.inspect}" unless $?.success?
  end
end
