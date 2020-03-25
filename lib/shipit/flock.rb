# typed: true
require 'English'
require 'timeout'
require 'pathname'

module Shipit
  class Flock
    TimeoutError = Class.new(::Timeout::Error)

    attr_reader :path

    def initialize(path)
      @path = Pathname.new(path)
    end

    def lock(timeout:)
      path.parent.mkpath
      path.open('w') do |file|
        if retrying(timeout: timeout) { file.flock(File::LOCK_EX | File::LOCK_NB) }
          file.write($PROCESS_ID.to_s)
          return yield
        else
          raise TimeoutError, "Couldn't acquire lock for #{path} in #{timeout} seconds"
        end
      end
    end

    private

    def retrying(timeout:, breathing_time: 0.01)
      started_at = Time.now.to_f

      loop do
        if yield
          return true
        elsif Time.now.to_f - started_at < timeout
          sleep(breathing_time)
        else
          return false
        end
      end
    end
  end
end
