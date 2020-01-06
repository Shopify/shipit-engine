module Shipit
  class BackgroundJob
    module Unique
      extend ActiveSupport::Concern
      DEFAULT_TIMEOUT = 10

      ConcurrentJobError = Class.new(StandardError)

      included do
        around_perform { |job, block| job.acquire_lock(&block) }
        cattr_accessor :lock_timeout
        on_duplicate :retry
      end

      def acquire_lock(&block)
        mutex = Redis::Lock.new(
          lock_key(*arguments),
          Shipit.redis,
          expiration: self.class.timeout || DEFAULT_TIMEOUT,
          timeout: self.class.lock_timeout || 0,
        )
        mutex.lock(&block)
      rescue Redis::Lock::LockTimeout
        raise ConcurrentJobError unless self.class.drop_duplicate_jobs?
      end

      def lock_key(*args)
        ActiveJob::Arguments.serialize([self.class.name] + args).join('-')
      end

      module ClassMethods
        ACTIONS = %i(retry drop).freeze
        ACTIONS_LIST = ACTIONS.map(&:inspect).join(', ').freeze
        def on_duplicate(action)
          unless ACTIONS.include?(action)
            raise ArgumentsError, "invalid action: #{action.inspect}, should be one of #{ACTIONS_LIST}"
          end

          @on_duplicate = action
        end

        def drop_duplicate_jobs?
          @on_duplicate == :drop
        end
      end
    end
  end
end
