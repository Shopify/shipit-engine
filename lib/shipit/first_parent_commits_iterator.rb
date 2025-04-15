# frozen_string_literal: true

module Shipit
  class FirstParentCommitsIterator < OctokitIterator
    def each
      last_ancestor = nil
      super do |commit|
        unless last_ancestor
          yield last_ancestor = commit
          next
        end

        yield last_ancestor = commit if last_ancestor.parents.empty? || last_ancestor.parents.first.sha == commit.sha
      end
    end
  end
end
