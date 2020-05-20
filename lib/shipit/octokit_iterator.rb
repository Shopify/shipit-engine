# frozen_string_literal: true
module Shipit
  class OctokitIterator
    include Enumerable

    def initialize(relation = nil)
      @response = if relation
        relation.get(per_page: 100)
      else
        yield
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
