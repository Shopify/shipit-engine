class FirstParentCommitsIterator < OctokitIterator
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
