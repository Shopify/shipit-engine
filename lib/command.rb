require 'pty'
require 'shellwords'
require 'fileutils'
require 'timeout'

class Command
  MAX_READ = 64.kilobytes

  Error = Class.new(StandardError)

  attr_reader :out, :code, :chdir, :env, :args, :pid, :timeout

  def initialize(*args, default_timeout: 5.minutes.to_i, env: {}, chdir:)
    @args, options = parse_arguments(args)
    @timeout = options['timeout'.freeze] || options[:timeout] || default_timeout
    @env = env
    @chdir = chdir.to_s
  end

  def to_s
    @args.join(' ')
  end

  def interpolate_environment_variables(argument)
    return argument.map { |a| interpolate_environment_variables(a) } if argument.is_a?(Array)

    argument.gsub(/(\$\w+)/) do |variable|
      variable.sub!('$', '')
      Shellwords.escape(@env.fetch(variable) { ENV[variable] })
    end
  end

  def success?
    code == 0
  end

  def exit_message
    "#{self} exited with status #{@code}"
  end

  def run
    output = []
    stream do |out|
      output << out
    end
    output.join
  end

  def run!
    output = []
    stream! do |out|
      output << out
    end
    output.join
  end

  def with_full_path
    old_path = ENV['PATH']
    ENV['PATH'] = "#{ENV['PATH']}:#{Shipit::Engine.root.join('lib', 'snippets')}"
    yield
  ensure
    ENV['PATH'] = old_path
  end

  def interpolated_arguments
    interpolate_environment_variables(@args)
  end

  def start
    return if @started
    child_in = @out = @pid = nil
    FileUtils.mkdir_p(@chdir)
    with_full_path do
      @out, child_in, @pid = PTY.spawn(@env, *interpolated_arguments, chdir: @chdir)
      child_in.close
    end
    @started = true
    self
  end

  def stream(&block)
    yield "\n#{args.inspect} in #{@chdir}\n"
    start
    begin
      read_stream(@out, &block)
    rescue Timeout::Error => error
      @code = 'timeout'
      yield red("No output received in the last #{timeout} seconds.") + "\n"
      terminate!(&block)
      raise error
    rescue Errno::EIO # Somewhat expected on Linux: http://stackoverflow.com/a/10306782
    end

    _, status = Process.waitpid2(@pid)
    @code = status.exitstatus
    yield exit_message + "\n" unless success?

    self
  end

  def check_status
  end

  def red(text)
    "\033[1;31m#{text}\033[0m"
  end

  def stream!(&block)
    stream(&block)
    raise Command::Error.new(exit_message) unless success?
    self
  end

  def read_stream(io)
    loop do
      with_timeout do
        yield io.readpartial(MAX_READ)
      end
    end
  rescue EOFError
  end

  def with_timeout(&block)
    return yield unless timeout

    Timeout.timeout(timeout, &block)
  end

  def terminate!(&block)
    kill_and_wait('INT', 5, &block)
    kill_and_wait('INT', 2, &block)
    kill_and_wait('TERM', 5, &block)
    kill_and_wait('TERM', 2, &block)
    kill('KILL', &block)
  rescue Errno::ECHILD
    true # much success
  ensure
    begin
      read_stream(@out, &block)
    rescue
    end
  end

  def kill_and_wait(sig, wait, &block)
    kill(sig, &block)
    Timeout.timeout(wait) do
      read_stream(@out, &block)
    end
  rescue Timeout::Error
  end

  def kill(sig)
    yield red("Sending SIG#{sig} to PID #{@pid}\n")
    Process.kill(sig, @pid)
  end

  def parse_arguments(arguments)
    options = {}
    args = arguments.flatten.map do |argument|
      case argument
      when Hash
        options.merge!(argument.values.first)
        argument.keys.first
      else
        argument
      end
    end
    return args, options
  end
end
