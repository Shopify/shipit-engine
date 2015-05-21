module Shipit
  class SimpleMessageVerifier < ActiveSupport::MessageVerifier
    def initialize(secret, options = {})
      options[:serializer] ||= ToS
      secret += Rails.application.secrets.secret_key_base
      super(secret, options)
    end

    private

    def encode(data)
      data.to_s
    end

    def decode(data)
      data
    end

    module ToS
      def self.dump(object)
        object.to_s
      end

      def self.load(payload)
        payload
      end
    end
  end
end
