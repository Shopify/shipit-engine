class Rollback < Deploy
  def rollback?
    true
  end

  def rollbackable?
    false
  end

  def commits
    return Commit.none unless stack

    @commits ||= stack.commits.reachable.newer_than(until_commit_id).until(since_commit_id).order(id: :asc)
  end

  def commit_range
    [until_commit, since_commit]
  end

  def to_partial_path
    'deploys/deploy'
  end
end
