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
      @task.ping
      @task.run!
      checkout_repository
      perform_task
      @task.write("\nCompleted successfully\n")
      @task.report_complete!
    rescue Command::TimedOut => error
      @task.write("\n#{error.message}\n")
      @task.report_timeout!(error)
    rescue Command::Error => error
      @task.write("\n#{error.message}\n")
      @task.report_failure!(error)
    rescue StandardError => error
      @task.report_error!(error)
    rescue Exception => error
      @task.report_error!(error)
      raise
    end

    def abort!(signal: 'TERM')
      pid = @task.pid
      if pid
        @task.write("$ kill #{pid}\n")
        Process.kill(signal, pid)
      else
        @task.write("Can't abort, no recorded pid, WTF?\n")
      end
    rescue SystemCallError => error
      @task.write("kill: (#{pid}) - #{error.message}\n")
    end

    def check_for_abort
      @task.should_abort? do |times_killed|
        if times_killed > 3
          abort!(signal: 'KILL')
        else
          abort!
        end
      end
    end

    def perform_task
      capture_all! @commands.install_dependencies
      capture_all! @commands.perform
    end

    def checkout_repository
      unless @commands.fetched?(@task.until_commit).tap(&:run).success?
        # acquire_git_cache_lock can take upto 15 seconds
        # to process. Try to make sure that the job isn't
        # marked dead while we attempt to acquire the lock.
        @task.ping
        @task.acquire_git_cache_lock do
          @task.ping
          unless @commands.fetched?(@task.until_commit).tap(&:run).success?
            capture! @commands.fetch
          end
        end
      end
      capture_all! @commands.clone
      capture! @commands.checkout(@task.until_commit)
    end

    def capture_all!(commands)
      commands.map { |c| capture!(c) }
    end

    def capture!(command)
      command.start do
        @task.ping
        check_for_abort
      end
      @task.write("$ #{command}\npid: #{command.pid}\n")
      @task.pid = command.pid
      command.stream! do |line|
        @task.write(line)
      end
      @task.write("\n")
      command.success?
    end

    def capture(command)
      capture!(command)
      command.success?
    rescue Command::Error
      false
    end
  end
end
