# frozen_string_literal: true

module Shipit
  module LockProviders
    class Config
      class MissingConfigError < StandardError; end
      attr_accessor :provider

      class << self
        def configure
          yield config
          config
        end

        def config
          @config ||= new(provider: NullProvider)
        end
      end

      def initialize(provider:)
        @provider = provider
      end
    end
  end
end
