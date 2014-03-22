require "open3"
require 'fileutils'

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

  def run!
    output = []
    stream! do |out|
      output << out
    end
    output.join
  end

  def stream(&block)
    FileUtils.mkdir_p(@chdir)
    _in, @out, wait_thread = Open3.popen2e(@env, *@args, chdir: @chdir)
    _in.close
    read_stream(@out, &block)
    @code = wait_thread.value
    yield exit_message + "\n" unless success?
    self
  end

  def stream!(&block)
    stream(&block)
    raise Command::Error.new(exit_message) unless success?
    self
  end

  def read_stream(io, &block)
    loop do
      yield io.readpartial(MAX_READ)
    end
  rescue EOFError
  end

end
