require "open3"

class Command
  attr_reader :out, :code

  def initialize(*args)
    @args = args
  end

  def to_s
    @args.join(' ')
  end

  def success?
    code == 0
  end

  def stream(&block)
    _in, @out, wait_thread = Open3.popen2e(*@args)
    _in.close
    @out.each_line(&block) if block
    @code = wait_thread.value
    self
  end

end
