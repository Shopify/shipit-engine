module CommitsHelper
  def create_revert(parent_commit, pr: false)
    message = []

    if pr
      message << "Merge pull request #12345 from Shopify/revert-that-other-thing"
      message << ""
    end

    message << "Revert \"#{parent_commit.message}\""

    parent_commit.stack.commits.create!(
      author: parent_commit.author,
      committer: parent_commit.committer,
      sha: SecureRandom.hex,
      authored_at: parent_commit.authored_at + 1.minute,
      committed_at: parent_commit.committed_at + 1.minute,
      message: message.join("\n"),
    )
  end
end
