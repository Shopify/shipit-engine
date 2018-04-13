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
