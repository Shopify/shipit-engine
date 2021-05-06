# frozen_string_literal: true
require 'pty'
require 'shellwords'
require 'fileutils'
require 'timeout'

module Shipit
  class Command
    MAX_READ = 64.kilobytes

    Error = Class.new(StandardError)
    NotFound = Class.new(Error)
    Denied = Class.new(Error)
    TimedOut = Class.new(Error)

    BASE_ENV = Bundler.unbundled_env.merge((ENV.keys - Bundler.unbundled_env.keys).map { |k| [k, nil] }.to_h)

    class Failed < Error
      attr_reader :exit_code

      def initialize(message, exit_code)
        super(message)
        @exit_code = exit_code
      end
    end

    attr_reader :out, :chdir, :env, :args, :pid, :timeout

    def initialize(*args, default_timeout: Shipit.default_inactivity_timeout, env: {}, chdir:)
      @args, options = parse_arguments(args)
      @timeout = options['timeout'] || options[:timeout] || default_timeout
      @env = env.transform_values(&:to_s)
      @chdir = chdir.to_s
      @timed_out = false
    end

    def with_timeout(new_timeout)
      old_timeout = timeout
      @timeout = new_timeout
      yield
    ensure
      @timeout = old_timeout
    end

    def to_s
      @args.join(' ')
    end

    def interpolate_environment_variables(argument)
      return argument.map { |a| interpolate_environment_variables(a) } if argument.is_a?(Array)

      EnvironmentVariables.with(env).interpolate(argument)
    end

    def success?
      !code.nil? && code.zero?
    end

    def exit_message
      "#{self} #{termination_status}"
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

    def interpolated_arguments
      interpolate_environment_variables(@args)
    end

    def start(&block)
      return if @started
      @control_block = block
      @out = @pid = nil
      FileUtils.mkdir_p(@chdir)
      begin
        @out, child_in, @pid = PTY.spawn(unbundled_env, *interpolated_arguments, chdir: @chdir)
        child_in.close
      rescue Errno::ENOENT
        raise NotFound, "#{Shellwords.split(interpolated_arguments.first).first}: command not found"
      rescue Errno::EACCES
        raise Denied, "#{Shellwords.split(interpolated_arguments.first).first}: Permission denied"
      end
      @started = true
      self
    end

    def unbundled_env
      BASE_ENV.merge('PATH' => "#{ENV['PATH']}:#{Shipit.shell_paths.join(':')}").merge(@env.stringify_keys)
    end

    def stream(&block)
      start
      begin
        read_stream(@out, &block)
      rescue TimedOut => error
        yield red("No output received in the last #{timeout} seconds.") + "\n"
        terminate!(&block)
        raise error
      rescue Errno::EIO # Somewhat expected on Linux: http://stackoverflow.com/a/10306782
      end

      self
    ensure
      reap_child!
    end

    def red(text)
      "\033[1;31m#{text}\033[0m"
    end

    def stream!(&block)
      stream(&block)
      raise Failed.new(exit_message, code) unless success?
      self
    end

    def timed_out?
      @timed_out
    end

    def output_timed_out?
      @last_output_at ||= Time.now.to_i
      (@last_output_at + timeout) < Time.now.to_i
    end

    def touch_last_output_at
      @last_output_at = Time.now.to_i
    end

    def yield_control
      @control_block&.call
    end

    def read_stream(io)
      touch_last_output_at
      loop do
        yield_control
        yield io.read_nonblock(MAX_READ)
        touch_last_output_at
      rescue IO::WaitReadable
        if output_timed_out?
          @timed_out = true
          raise TimedOut
        end
        IO.select([io], nil, nil, 1)
        retry
      end
    rescue EOFError
    end

    def terminate!(&block)
      kill_and_wait('INT', 5, &block) ||
        kill_and_wait('INT', 2, &block) ||
        kill_and_wait('TERM', 5, &block) ||
        kill_and_wait('TERM', 2, &block) ||
        kill('KILL', &block)
    rescue Errno::ECHILD, Errno::ESRCH
      true # much success
    ensure
      begin
        read_stream(@out, &block)
      rescue
      end
    end

    def kill_and_wait(sig, wait, &block)
      retry_count = 5
      kill(sig, &block)
      begin
        with_timeout(wait) do
          read_stream(@out, &block)
        end
      rescue TimedOut
      rescue Errno::EIO # EIO is somewhat expected on Linux: http://stackoverflow.com/a/10306782
        # If we try to read the stream right after sending a signal, we often get an Errno::EIO.
        if reap_child!(block: false)
          return true
        end
        # If we let the child a little bit of time, it solves it.
        retry_count -= 1
        if retry_count > 0
          sleep(0.05)
          retry
        end
      end
      reap_child!(block: false)
      true
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
      [args.map(&:to_s), options]
    end

    def running?
      !!pid && !@status
    end

    def code
      @status&.exitstatus
    end

    def signaled?
      @status.signaled?
    end

    def reap_child!(block: true)
      return @status if @status
      return unless running? # Command was never started e.g. permission denied, not found etc
      if block
        _, @status = Process.waitpid2(@pid)
      elsif res = Process.waitpid2(@pid, Process::WNOHANG)
        @status = res[1]
      end
      @status
    end

    def termination_status
      if running?
        "is running"
      elsif success?
        "terminated successfully"
      elsif timed_out? && signaled?
        "timed out and terminated with #{Signal.signame(@status.termsig)} signal"
      elsif timed_out?
        "timed out and terminated with exit status #{exitstatus}"
      elsif signaled?
        "terminated with #{Signal.signame(@status.termsig)} signal"
      else
        "terminated with exit status #{code}"
      end
    end
  end
end
