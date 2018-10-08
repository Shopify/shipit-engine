module Shipit
  class EphemeralCommitChecks
    FINAL_STATUSES = %w(failed error success).freeze

    def initialize(commit)
      @commit = commit
    end

    attr_accessor :status
    attr_reader :output

    def run
      self.status = 'running'
      commands = StackCommands.new(stack)
      commands.with_temporary_working_directory(commit: commit) do |directory|
        deploy_spec = DeploySpec::FileSystem.new(directory, stack.environment)
        capture_all(build_commands(deploy_spec.dependencies_steps, chdir: directory))
        capture_all(build_commands(deploy_spec.review_checks, chdir: directory))
      end
      self
    rescue Command::Error
      self.status = 'failed'
      self
    rescue
      self.status = 'error'
      raise
    else
      self.status = 'success'
      self
    end

    def success?
      status == 'success'
    end

    def finished?
      FINAL_STATUSES.include?(status)
    end

    def write(output)
      @output ||= ''
      @output += output
    end

    private

    def build_commands(commands, chdir:)
      commands.map { |c| Command.new(c, env: Shipit.env, chdir: chdir) }
    end

    def capture_all(commands)
      commands.map { |c| capture(c) }
    end

    def capture(command)
      command.start
      write("$ #{command}\n")
      command.stream! do |line|
        write(line)
      end
    rescue Command::Error => error
      write(error.message)
      raise
    ensure
      write("\n")
    end

    attr_reader :commit

    def stack
      @stack ||= commit.stack
    end
  end
end
