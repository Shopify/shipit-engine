require 'test_helper'

module Shipit
  class RollbackTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @rollback = Rollback.new
    end

    test "#rollback? returns true" do
      assert @rollback.rollback?
    end

    test "#rollbackable? returns false" do
      refute @rollback.rollbackable?
    end

    test "#supports_rollback? returns false" do
      refute @rollback.supports_rollback?
    end

    test "when a rollback succeed reverted commits are locked" do
      @stack.tasks.where.not(id: shipit_tasks(:shipit_complete).id).delete_all

      deploy = @stack.deploys.success.last
      reverted_commit = deploy.until_commit

      @stack.commits.create!(
        sha: '50ce7d4440fcd8c734f8b7b76c86f8db46706e4f',
        message: %(Revert "#{reverted_commit.message_header}"),
        author: reverted_commit.author,
        committer: reverted_commit.committer,
        authored_at: Time.zone.now,
        committed_at: Time.zone.now,
      )

      expected = [
        ['Revert "Merge pull request #7 from shipit-engine/yoloshipit"', false, nil],
        ["whoami", false, nil],
        ['fix all the things', false, nil],
      ]
      assert_equal(expected, @stack.undeployed_commits.map { |c| [c.title, c.locked?, c.lock_author_id] })

      rollback = deploy.trigger_revert
      rollback.run!
      rollback.complete!

      user_id = reverted_commit.author.id
      expected = [
        ['Revert "Merge pull request #7 from shipit-engine/yoloshipit"', false, nil],
        ["whoami", true, user_id],
        ['fix all the things', true, user_id],
        ['yoloshipit!', true, user_id],
      ]
      assert_equal(expected, @stack.undeployed_commits.map { |c| [c.title, c.locked?, c.lock_author_id] })
    end
  end
end
