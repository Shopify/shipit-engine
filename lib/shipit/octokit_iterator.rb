# frozen_string_literal: true
module Shipit
  class OctokitIterator
    include Enumerable

    def initialize(relation = nil)
      if relation
        @response = relation.get(per_page: 100)
      else
        yield Shipit.github.api
        @response = Shipit.github.api.last_response
      end
    rescue Octokit::Conflict
      # Repository is empty...
    end

    def each(&block)
      response = @response
      return unless response

      loop do
        response.data.each(&block)
        return unless response.rels[:next]
        response = response.rels[:next].get
      end
    end
  end
end
