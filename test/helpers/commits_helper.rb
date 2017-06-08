module CommitsHelper
  def create_revert(commit, pr: false)
    message = []

    if pr
      message << "Merge pull request #12345 from Shopify/revert-that-other-thing"
      message << ""
    end

    message << "Revert \"#{commit.message}\""

    commit.stack.commits.create!(
      author: commit.author,
      committer: commit.committer,
      sha: SecureRandom.hex,
      authored_at: commit.authored_at + 1.minute,
      committed_at: commit.committed_at + 1.minute,
      message: message.join("\n"),
    )
  end
end
