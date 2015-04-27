class BackgroundJob
  module Unique
    extend ActiveSupport::Concern

    DEFAULT_TIMEOUT = 10

    included do
      around_perform { |job, block| job.acquire_lock(&block) }
    end

    module ClassMethods
      def redis_namespace
        @redis_namespace ||= Redis::Namespace.new("#{Resque.redis.namespace}:#{name}", redis: Shipit.redis)
      end
    end

    delegate :redis_namespace, to: :class

    def acquire_lock(&block)
      mutex = Redis::Lock.new(
        lock_key(*arguments),
        expiration: self.class.timeout || DEFAULT_TIMEOUT,
        timeout: 0,
      )
      mutex.lock(&block)
    end

    def lock_key(*args)
      args.map { |arg| hash_argument(arg) }.join('-')
    end

    private

    def hash_argument(argument)
      return argument.to_global_id.to_s if argument.respond_to?(:to_global_id)
      argument.to_s
    end
  end
end
