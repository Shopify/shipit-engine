# frozen_string_literal: true
module Shipit
  class Delivery < Record
    STATUSES = %w(pending scheduled sent).freeze
    enum status: STATUSES.zip(STATUSES).to_h

    belongs_to :hook

    validates :url, presence: true, url: { no_local: true, allow_blank: true }
    validates :content_type, presence: true

    serialize :response_headers, SafeJSON

    after_commit :purge_old_deliveries, on: :create

    def schedule!
      DeliverHookJob.perform_later(self)
      scheduled!
    end

    def send!
      update!(response: http.post(url, payload), status: 'sent', delivered_at: Time.now)
    end

    def response=(response)
      self.response_code = response.status
      self.response_headers = response.headers
      self.response_body = response.body
    end

    private

    def purge_old_deliveries
      PurgeOldDeliveriesJob.perform_later(hook)
    end

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
        'X-Shipit-Delivery' => id.to_s,
        'Accept' => '*/*',
      }
    end
  end
end
