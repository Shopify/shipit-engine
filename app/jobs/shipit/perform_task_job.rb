module Shipit
  class PerformTaskJob < BackgroundJob
    queue_as :deploys

    def perform(task)
      @task = task
      @commands = Commands.for(@task)
      unless @task.pending?
        logger.error("Task ##{@task.id} already in `#{@task.status}` state. Aborting.")
        return
      end
      run
    ensure
      @commands.clear_working_directory
    end

    def run
      @task.run!
      checkout_repository
      perform_task
      @task.complete!
    rescue Command::Error => error
      @task.write("\n#{error.message}\n")
      @task.report_failure!(error)
    rescue StandardError => error
      @task.report_error!(error)
    rescue Exception => error
      @task.report_error!(error)
      raise
    end

    def perform_task
      Bundler.with_clean_env do
        capture_all @commands.install_dependencies
        capture_all @commands.perform
      end
    end

    def checkout_repository
      @task.acquire_git_cache_lock do
        capture @commands.fetch
        capture @commands.clone
      end
      capture @commands.checkout(@task.until_commit)
    end

    def capture_all(commands)
      commands.map { |c| capture(c) }
    end

    def capture(command)
      command.start
      @task.write("$ #{command}\npid: #{command.pid}\n")
      @task.pid = command.pid
      command.stream! do |line|
        @task.write(line)
      end
      @task.write("\n")
    end
  end
end
