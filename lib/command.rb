require 'open3'
require 'fileutils'
require 'timeout'

class Command
  MAX_READ = 2 ** 16

  Error = Class.new(StandardError)

  attr_reader :out, :code, :chdir, :env, :args

  def initialize(*args, env: {}, chdir: )
    @args = args
    @env = env
    @chdir = chdir.to_s
  end

  def to_s
    "#{format_env} #{@args.join(' ')}"
  end

  def format_env
    @env.map { |pair| pair.map(&:to_s).join('=') }.join(' ')
  end

  def success?
    code == 0
  end

  def exit_message
    "#{self.to_s} exited with status #{@code}"
  end

  def run(timeout: nil)
    output = []
    stream(timeout: timeout) do |out|
      output << out
    end
    output.join
  end

  def run!(timeout: nil)
    output = []
    stream!(timeout: timeout) do |out|
      output << out
    end
    output.join
  end

  def with_full_path
    old_path = ENV['PATH']
    ENV['PATH'] = "#{ENV['PATH']}:#{Rails.root.join('lib', 'snippets')}"
    yield
  ensure
    ENV['PATH'] = old_path
  end

  def stream(timeout: nil, &block)
    FileUtils.mkdir_p(@chdir)
    _in, @out, wait_thread = []
    with_full_path do
      _in, @out, wait_thread = Open3.popen2e(@env, *@args, chdir: @chdir)
      _in.close
      begin
        read_stream(@out, timeout: timeout, &block)
      rescue Timeout::Error => error
        wait_thread.kill
        @code = 'timeout'
        yield red("No output received in the last #{timeout} seconds.") + "\n"
        raise
      else
        @code = wait_thread.value
        yield exit_message + "\n" unless success?
      end
    end
    self
  end

  def red(text)
    "\033[1;31m#{text}\033[0m"
  end

  def stream!(timeout: nil, &block)
    stream(timeout: timeout, &block)
    raise Command::Error.new(exit_message) unless success?
    self
  end

  def read_stream(io, timeout: timeout, &block)
    loop do
      with_timeout(timeout) do
        yield io.readpartial(MAX_READ)
      end
    end
  rescue EOFError
  end

  def with_timeout(timeout, &block)
    return yield unless timeout

    Timeout.timeout(timeout, &block)
  end

end
