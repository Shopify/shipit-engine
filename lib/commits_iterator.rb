class CommitsIterator
  include Enumerable
  MAX_PAGES = 2

  def initialize(commits_relation, max_pages = MAX_PAGES)
    @relation = commits_relation
    @max_pages = max_pages
  end

  def each(&block)
    resource = @relation

    loop do
      resource.data.each(&block)

      @max_pages -= 1
      return if @max_pages <= 0 || !resource.rels[:next]

      resource = resource.rels[:next].get
    end
  end
end
