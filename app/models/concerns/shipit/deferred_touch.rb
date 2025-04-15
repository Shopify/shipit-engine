# frozen_string_literal: true

module Shipit
  module DeferredTouch
    extend ActiveSupport::Concern

    SET_KEY = 'shipit:deferred_touches'
    TMP_KEY = "#{SET_KEY}:updating".freeze
    CACHE_KEY = "#{SET_KEY}:scheduled".freeze
    THROTTLE_TTL = 1.second

    included do
      class_attribute :deferred_touches, instance_accessor: false
      after_commit :schedule_touches
    end

    class << self
      attr_accessor :enabled

      def touch_now!
        now = Time.now.utc
        fetch do |touches|
          records = []
          touches.each do |model, changes|
            changes.each do |attribute, ids|
              records << [model.where(id: ids).to_a, attribute]
            end
          end

          ActiveRecord::Base.transaction do
            records.each do |instances, attribute|
              instances.each { |i| i.touch(attribute, time: now) }
            end
          end
        end
      end

      private

      def fetch
        fetch_members do |records|
          return if records.empty?

          records = records.each_with_object({}) do |(model, id, attribute), hash|
            attributes = (hash[model] ||= {})
            ids = (attributes[attribute] ||= [])
            ids << id
          end
          yield records.transform_keys(&:constantize)
        end
      end

      def fetch_members
        Shipit.redis.multi do |transaction|
          transaction.sunionstore(TMP_KEY, SET_KEY)
          transaction.del(SET_KEY)
        end

        yield Shipit.redis.smembers(TMP_KEY).map { |r| r.split('|') }

        Shipit.redis.del(TMP_KEY)
      end
    end

    self.enabled = true

    module ClassMethods
      def deferred_touch(touches)
        touches = touches.transform_values(&Array.method(:wrap))
        self.deferred_touches = touches.flat_map do |association_name, attributes|
          association = reflect_on_association(association_name)
          Array.wrap(attributes).map do |attribute|
            [association.klass.name, association.foreign_key, attribute]
          end
        end
      end
    end

    private

    def schedule_touches
      return unless self.class.deferred_touches

      deferred_touches = self.class.deferred_touches.reject do |m, _fk, _a|
        ActiveRecord::NoTouching.applied_to?(m.constantize)
      end
      return if deferred_touches.empty?

      touches = deferred_touches.map { |m, fk, a| [m, self[fk], a].join('|') }
      Shipit.redis.sadd(SET_KEY, touches)
      if DeferredTouch.enabled
        Rails.cache.fetch(CACHE_KEY, expires_in: THROTTLE_TTL) do
          DeferredTouchJob.perform_later
          true
        end
      else
        DeferredTouch.touch_now!
      end
    end
  end
end
