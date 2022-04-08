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
      @lock ||= Redis::Lock.new(key('lock'), Shipit.redis, expiration: 1, timeout: 2)
      @lock.lock(&block)
    end

    def schedule
      return false if Shipit.redis.get(key('status')).present?
      synchronize do
        return false if Shipit.redis.get(key('status')).present?

        initialize_redis_state
      end
      PerformCommitChecksJob.perform_later(commit: commit)
      true
    end

    def initialize_redis_state
      Shipit.redis.set(key('status'), 'scheduled', ex: OUTPUT_TTL)
      @status = 'scheduled'
    end

    def status
      @status ||= Shipit.redis.get(key('status'))
    end

    def status=(status)
      Shipit.redis.set(key('status'), status)
      @status = status
    end

    def output(since: 0)
      Shipit.redis.getrange(key('output'), since, -1)
    end

    def write(output)
      Shipit.redis.pipelined do |pipeline|
        pipeline.append(key('output'), output)
        pipeline.expire(key('output'), OUTPUT_TTL)
      end
    end

    private

    def key(key)
      "commit:#{commit.id}:checks:#{key}"
    end
  end
end
