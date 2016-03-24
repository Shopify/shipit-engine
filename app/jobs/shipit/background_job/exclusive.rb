module Shipit
  class BackgroundJob
    module Exclusive
      extend ActiveSupport::Concern

      DEFAULT_TIMEOUT = 10

      included do
        around_perform { |job, block| job.acquire_lock(&block) }
        cattr_accessor :lock_timeout

        rescue_from Redis::Lock::LockTimeout do
          retry_job wait: 15.seconds
        end
      end

      def acquire_lock(&block)
        mutex = Redis::Lock.new(
          lock_key(*arguments),
          Shipit.redis,
          expiration: self.class.timeout || DEFAULT_TIMEOUT,
          timeout: self.class.lock_timeout || 0,
        )
        mutex.lock(&block)
      end

      def lock_key(*args)
        ActiveJob::Arguments.serialize([self.class.name] + args).join('-')
      end
    end
  end
end
