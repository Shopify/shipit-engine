class PerformTaskJob < BackgroundJob
  COMMAND_TIMEOUT = 5.minutes.to_i
  @queue = :deploys

  extend BackgroundJob::StackExclusive

  def perform(params)
    @task = Task.find(params[:task_id])
    unless @task.pending?
      logger.error("Task ##{@task.id} already in `#{@task.status}` state. Aborting.")
      return
    end

    @task.run!
    commands = Commands.for(@task)
    capture commands.fetch
    capture commands.clone
    capture commands.checkout(@task.until_commit)

    record_deploy_spec!

    Bundler.with_clean_env do
      capture_all commands.install_dependencies
      capture_all commands.perform
    end
    @task.complete!
  rescue Command::Error
    @task.failure!
  rescue StandardError => error
    @task.write("#{error.class}: #{error.message}\n\t#{error.backtrace.join("\t")}\n")
    @task.error!
  ensure
    Resque.enqueue(FetchDeployedRevisionJob, stack_id: @task.stack_id)
    @task.clear_working_directory
  end

  def capture_all(commands)
    commands.map { |c| capture(c) }
  end

  def capture(command)
    command.start
    @task.write("$ #{command}\npid: #{command.pid}\n")
    @task.pid = command.pid
    command.stream!(timeout: COMMAND_TIMEOUT) do |line|
      @task.write(line)
    end
    @task.write("\n")
  end

  def record_deploy_spec!
    @task.stack.update(cached_deploy_spec: @task.spec)
  end
end
