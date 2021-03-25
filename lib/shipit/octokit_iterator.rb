# frozen_string_literal: true
module Shipit
  class OctokitIterator
    include Enumerable

    def initialize(relation = nil, github_client: nil)
      if relation
        @response = relation.get(per_page: 100)
      else
        data = yield github_client
        @response = github_client.last_response if data.present?
      end
    end

    def each(&block)
      response = @response

      loop do
        response.data.each(&block)
        return unless response.rels[:next]
        response = response.rels[:next].get
      end
    end
  end
end
