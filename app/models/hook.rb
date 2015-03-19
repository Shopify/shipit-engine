class Hook < ActiveRecord::Base
  CONTENT_TYPES = {
    'json' => 'application/json',
    'form' => 'application/x-www-form-urlencoded',
  }.freeze

  EVENTS = %w(
    task
    deploy
    rollback
  ).freeze

  belongs_to :stack, required: false
  has_many :deliveries

  validates :url, presence: true, url: {no_local: true, allow_blank: true}
  validates :content_type, presence: true, inclusion: {in: CONTENT_TYPES.keys}

  serialize :events, CSVSerializer

  scope :for_stack, -> (stack_id) { where(stack_id: [nil, stack_id]) }

  class << self
    def emit(event, stack, payload)
      Resque.enqueue(EmitEventJob, event: event, stack_id: stack.try!(:id), payload: coerce_payload(payload))
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
      coerced_payload.as_json
    end
  end

  def deliver!(event, payload)
    deliveries.create!(
      event: event,
      url: url,
      content_type: CONTENT_TYPES[content_type],
      payload: serialize_payload(payload),
    ).schedule!
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
