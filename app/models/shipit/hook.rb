module Shipit
  class Hook < ActiveRecord::Base
    default_scope { order :id }

    DELIVERIES_LOG_SIZE = 500

    CONTENT_TYPES = {
      'json' => 'application/json',
      'form' => 'application/x-www-form-urlencoded',
    }.freeze

    EVENTS = %w(
      stack
      task
      deploy
      rollback
      lock
      commit_status
      deployable_status
      merge_status
      merge
    ).freeze

    belongs_to :stack, required: false
    has_many :deliveries

    validates :delivery_url, presence: true, url: {no_local: true, allow_blank: true}
    validates :content_type, presence: true, inclusion: {in: CONTENT_TYPES.keys}
    validates :events, presence: true, subset: {of: EVENTS}

    serialize :events, Shipit::CSVSerializer

    scope :global, -> { where(stack_id: nil) }
    scope :scoped_to, -> (stack) { where(stack_id: stack.id) }
    scope :for_stack, -> (stack_id) { where(stack_id: [nil, stack_id]) }

    class << self
      def emit(event, stack, payload)
        raise "#{event} is not declared in Shipit::Hook::EVENTS" unless EVENTS.include?(event.to_s)
        Shipit::EmitEventJob.perform_later(
          event: event.to_s,
          stack_id: stack.try!(:id),
          payload: coerce_payload(payload),
        )
      end

      def deliver(event, stack_id, payload)
        for_stack(stack_id).listening_event(event).each do |hook|
          hook.deliver!(event, payload)
        end
      end

      def listening_event(event)
        event = event.to_s
        all.to_a.select { |h| h.events.include?(event) }
      end

      def coerce_payload(payload)
        coerced_payload = payload.dup
        payload.each do |key, value|
          if serializer = ActiveModel::Serializer.serializer_for(value)
            coerced_payload[key] = serializer.new(value)
          end
        end
        coerced_payload.to_json
      end
    end

    def scoped?
      stack_id?
    end

    def deliver!(event, payload)
      deliveries.create!(
        event: event,
        url: delivery_url,
        content_type: CONTENT_TYPES[content_type],
        payload: serialize_payload(payload),
      ).schedule!
    end

    def purge_old_deliveries!(keep: DELIVERIES_LOG_SIZE)
      if cut_off_time = deliveries.order(created_at: :desc).limit(1).offset(keep).pluck(:created_at).first
        deliveries.where('created_at > ?', cut_off_time).delete_all
      end
    end

    private

    def serialize_payload(payload)
      if content_type == 'form'
        payload.to_query
      else
        JSON.pretty_generate(payload)
      end
    end
  end
end
