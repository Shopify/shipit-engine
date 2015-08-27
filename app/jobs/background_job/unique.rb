class BackgroundJob
  module Unique
    extend ActiveSupport::Concern

    DEFAULT_TIMEOUT = 10

    included do
      around_perform { |job, block| job.acquire_lock(&block) }
      cattr_accessor :lock_timeout
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
