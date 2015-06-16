class CommitChecks
  OUTPUT_TTL = 10.minutes.to_i
  FINAL_STATUSES = %w(failed error success)

  def initialize(commit)
    @commit = commit
  end

  def run
    self.status = 'running'
    commands = StackCommands.new(stack)
    commands.with_temporary_working_directory(commit: commit) do |directory|
      deploy_spec = DeploySpec::FileSystem.new(directory, stack.environment)
      Bundler.with_clean_env do
        capture_all(build_commands(deploy_spec.dependencies_steps, chdir: directory))
        capture_all(build_commands(deploy_spec.review_checks, chdir: directory))
      end
    end
  rescue Command::Error
    self.status = 'failed'
  rescue
    self.status = 'error'
    raise
  else
    self.status = 'success'
  end

  def fetch
    @output ||= begin
      if redis.set('output', '', ex: OUTPUT_TTL, nx: true)
        self.status = 'scheduled'
        PerformCommitChecksJob.perform_later(commit: commit)
      end
      redis.get('output').to_s
    end
  end

  def status
    @status ||= redis.get('status')
  end

  def status=(status)
    redis.set('status', status, ex: OUTPUT_TTL)
    @status = status
  end

  def finished?
    FINAL_STATUSES.include?(status)
  end

  def output(since: 0)
    return fetch if since.zero?
    redis.getrange('output', since, -1)
  end

  def write(output)
    redis.append('output', output)
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

  def redis
    @redis ||= Shipit.redis("commit:#{commit.id}:checks")
  end

  def stack
    @stack ||= commit.stack
  end
end
