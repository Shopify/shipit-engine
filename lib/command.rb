require "open3"

class Command
  MAX_READ = 2 ** 16
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

  def stream(&block)
    _in, @out, wait_thread = Open3.popen2e(*@args)
    _in.close
    read_stream(@out, &block)
    @code = wait_thread.value
    self
  end

  def read_stream(io, &block)
    loop do
      yield io.readpartial(MAX_READ)
    end
  rescue EOFError
  end
end
