# frozen_string_literal: true
module Shipit
  class Hook < Record
    class DeliverySigner
      attr_reader :secret

      ALGORITHM = 'sha256'

      def initialize(secret)
        @secret = secret
      end

      def sign(payload)
        hmac = OpenSSL::HMAC.hexdigest(ALGORITHM, secret, payload)
        "#{ALGORITHM}=#{hmac}"
      end
    end

    class DeliverySpec
      def initialize(event:, url:, content_type:, payload:, secret:)
        @event = event
        @url = url
        @content_type = content_type
        @payload = payload
        @secret = secret
      end

      def send!
        http.post(url, payload)
      end

      private

      attr_reader :event, :url, :content_type, :payload, :secret

      def http
        Faraday::Connection.new do |connection|
          connection.headers = headers
          connection.adapter(Faraday.default_adapter)
        end
      end

      def headers
        {
          'User-Agent' => 'Shipit Webhook',
          'Content-Type' => content_type,
          'X-Shipit-Event' => event,
          'X-Shipit-Signature' => signature,
          'Accept' => '*/*',
        }
      end

      def signature
        return nil if secret.blank?

        DeliverySigner.new(secret).sign(payload)
      end
    end

    default_scope { order :id }

    DELIVERIES_LOG_SIZE = 500

    CONTENT_TYPES = {
      'json' => 'application/json',
      'form' => 'application/x-www-form-urlencoded',
    }.freeze

    EVENTS = %w(
      stack
      review_stack
      task
      deploy
      rollback
      lock
      commit_status
      deployable_status
      merge_status
      merge
      pull_request
    ).freeze

    belongs_to :stack, required: false
    has_many :deliveries

    validates :delivery_url, presence: true, url: { no_local: true, allow_blank: true }
    validates :content_type, presence: true, inclusion: { in: CONTENT_TYPES.keys }
    validates :events, presence: true, subset: { of: EVENTS }

    serialize :events, coder: Shipit::CSVSerializer

    scope :global, -> { where(stack_id: nil) }
    scope :scoped_to, ->(stack) { where(stack_id: stack.id) }
    scope :for_stack, ->(stack_id) { where(stack_id: [nil, stack_id]) }

    class << self
      def emit(event, stack, payload)
        raise "#{event} is not declared in Shipit::Hook::EVENTS" unless EVENTS.include?(event.to_s)
        Shipit::EmitEventJob.perform_later(
          event: event.to_s,
          stack_id: stack&.id,
          payload: coerce_payload(payload),
        )
        deliver_internal_hooks(event, stack, payload)
      end

      def deliver_internal_hooks(event, stack, payload)
        Shipit.internal_hook_receivers.each do |receiver|
          receiver.deliver(event, stack, payload)
        end
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
      DeliverHookJob.perform_later(
        event: event.to_s,
        url: delivery_url,
        content_type: CONTENT_TYPES[content_type],
        payload: serialize_payload(payload),
        secret: secret,
      )
    end

    def purge_old_deliveries!(keep: DELIVERIES_LOG_SIZE)
      delivery_ids = deliveries.sent.order(id: :desc).offset(keep).limit(50).pluck(:id)
      deliveries.where(id: delivery_ids).delete_all
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
