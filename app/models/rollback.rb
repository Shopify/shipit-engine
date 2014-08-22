class Rollback < Deploy

  def rollback?
    true
  end

  def commits
    return Commit.none unless stack

    @commits ||= stack.commits.reachable.newer_than(until_commit_id).until(since_commit_id).order(id: :asc)
  end

end
