require "open3"

class Command
  MAX_READ = 2 ** 16

  Error = Class.new(StandardError)

  attr_reader :out, :code

  def initialize(*args)
    @args = args
    @env = args.extract_options!
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

  def stream(&block)
    _in, @out, wait_thread = Open3.popen2e(*@args, :env => @env)
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
