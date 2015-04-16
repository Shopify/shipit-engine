class FirstParentCommitsIterator < OctokitIterator
  MAX_PAGE = 2

  def initialize(relation = nil, max_pages: MAX_PAGE, &block)
    super
  end

  def each
    last_ancestor = nil
    super do |commit|
      unless last_ancestor
        yield last_ancestor = commit
        next
      end

      if last_ancestor.parents.first.sha == commit.sha
        yield last_ancestor = commit
      end
    end
  end
end
