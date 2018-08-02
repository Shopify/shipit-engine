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
        ['Revert "Merge pull request #7 from shipit-engine/yoloshipit"', false],
        ["whoami", false],
        ['fix all the things', false],
      ]
      assert_equal expected, @stack.undeployed_commits.map { |c| [c.title, c.locked?] }

      rollback = deploy.trigger_revert
      rollback.run!
      rollback.complete!

      expected = [
        ['Revert "Merge pull request #7 from shipit-engine/yoloshipit"', false],
        ["whoami", true],
        ['fix all the things', true],
        ['yoloshipit!', true],
      ]
      assert_equal expected, @stack.undeployed_commits.map { |c| [c.title, c.locked?] }
    end
  end
end
