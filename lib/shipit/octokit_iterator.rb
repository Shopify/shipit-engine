# frozen_string_literal: true

module Shipit
  class OctokitIterator
    include Enumerable

    def initialize(relation = nil, github_api: nil)
      if relation
        @response = relation.get(per_page: 100)
      else
        data = yield github_api
        @response = github_api.last_response if data.present?
      end
    end

    def each(&block)
      response = @response

      loop do
        return unless response.present?

        response.data.each(&block)
        return unless response.rels[:next]

        response = response.rels[:next].get
      end
    end
  end
end
