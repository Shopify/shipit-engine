# frozen_string_literal: true

module Shipit
  module Webhooks
    module Handlers
      class Handler
        class << self
          attr_reader :param_parser

          def params(&block)
            @param_parser = ExplicitParameters::Parameters.define(&block)
          end

          def call(params)
            new(params).process
          end
        end

        attr_reader :params, :payload

        def initialize(payload)
          @payload = payload
          @params = self.class.param_parser.parse!(payload)
        end

        def process
          raise NotImplementedError
        end

        private

        def stacks
          @stacks ||= Repository.from_github_repo_name(repository_name)&.stacks || Stack.none
        end

        def repository_name
          payload.dig('repository', 'full_name')
        end
      end
    end
  end
end
