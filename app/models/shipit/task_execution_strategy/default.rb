# frozen_string_literal: true

module Shipit
  module TaskExecutionStrategy
    class Default < Base
      def execute
        @commands = Commands.for(@task)
        unless @task.pending?
          Rails.logger.error("Task ##{@task.id} already in `#{@task.status}` state. Aborting.")
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
      rescue Command::TimedOut => e
        @task.write("\n#{e.message}\n")
        @task.report_timeout!(e)
        failure!(e)
      rescue Command::Error => e
        @task.write("\n#{e.message}\n")
        @task.report_failure!(e)
        failure!(e)
      rescue StandardError => e
        @task.report_error!(e)
        failure!(e)
      rescue Exception => e
        @task.report_error!(e)
        failure!(e)
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
      rescue SystemCallError => e
        @task.write("kill: (#{pid}) - #{e.message}\n")
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
        capture_all!(@commands.install_dependencies)
        capture_all!(@commands.perform)
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
              capture!(@commands.fetch_commit(@task.until_commit))
            end
          end
        end
        capture_all!(@commands.clone)
        capture!(@commands.checkout(@task.until_commit))
      end

      def capture_all!(commands)
        commands.map { |c| capture!(c) }
      end

      def capture!(command)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        command.start do
          @task.ping
          check_for_abort
        end
        @task.write("\n$ #{command}\npid: #{command.pid}\n")
        @task.pid = command.pid
        command.stream! do |line|
          @task.write(line)
        end
        finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @task.write("pid: #{command.pid} finished in: #{(finished_at - started_at).round(3)} seconds\n")
        command.success?
      end

      def capture(command)
        capture!(command)
        command.success?
      rescue Command::Error
        false
      end

      def failure!(error)
        return unless @commands.respond_to?(:failed!)

        @commands.failed!(error.message)
        return unless @commands.respond_to?(:failure_step) && @commands.failure_step

        capture!(@commands.failure_step)
      end
    end
  end
end
