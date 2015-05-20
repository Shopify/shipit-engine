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
      ([self.class.name] + args).map { |arg| hash_argument(arg) }.join('-')
    end

    private

    def hash_argument(argument)
      return argument.to_global_id.to_s if argument.respond_to?(:to_global_id)
      argument.to_s
    end
  end
end
