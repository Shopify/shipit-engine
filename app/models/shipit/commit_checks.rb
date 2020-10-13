# frozen_string_literal: true
module Shipit
  class CommitChecks < EphemeralCommitChecks
    OUTPUT_TTL = 10.minutes.to_i
    FINAL_STATUSES = %w(failed error success).freeze

    def initialize(commit)
      @commit = commit
      super(commit)
    end

    def synchronize(&block)
      @lock ||= Redis::Lock.new('lock', redis, expiration: 1, timeout: 2)
      @lock.lock(&block)
    end

    def schedule
      return false if redis.get('status').present?
      synchronize do
        return false if redis.get('status').present?

        initialize_redis_state
      end
      PerformCommitChecksJob.perform_later(commit: commit)
      true
    end

    def initialize_redis_state
      redis.pipelined do
        redis.set('output', '', ex: OUTPUT_TTL)
        redis.set('status', 'scheduled', ex: OUTPUT_TTL)
      end
      @status = 'scheduled'
    end

    def status
      @status ||= redis.get('status')
    end

    def status=(status)
      redis.set('status', status)
      @status = status
    end

    def output(since: 0)
      redis.getrange('output', since, -1)
    end

    def write(output)
      redis.append('output', output)
    end

    private

    def redis
      @redis ||= Shipit.redis("commit:#{commit.id}:checks")
    end
  end
end
