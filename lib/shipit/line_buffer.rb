# frozen_string_literal: true

module Shipit
  class LineBuffer
    SEPARATOR = "\n"

    def initialize(queue = "")
      @queue = queue.dup
    end

    def buffer(text, &block)
      @queue << text
      whole_lines.each(&block).tap { flush }
    end

    def empty?
      @queue.empty?
    end

    private

    def whole_lines
      whole? ? lines : lines[0..-2]
    end

    def flush
      whole? ? clear : @queue = lines.last
    end

    def whole?
      @queue.end_with?(SEPARATOR)
    end

    def lines
      @queue.split(SEPARATOR)
    end

    def clear
      @queue.clear
    end
  end
end
