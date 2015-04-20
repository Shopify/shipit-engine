class OctokitIterator
  include Enumerable

  def initialize(relation = nil, max_pages: nil)
    if relation
      @response = relation.get(per_page: 100)
    else
      yield Shipit.github_api
      @response = Shipit.github_api.last_response
    end
    @max_pages = max_pages
  end

  def each(&block)
    response = @response

    loop do
      response.data.each(&block)

      return unless response.rels[:next]
      if @max_pages
        @max_pages -= 1
        return if @max_pages <= 0
      end

      response = response.rels[:next].get
    end
  end
end
