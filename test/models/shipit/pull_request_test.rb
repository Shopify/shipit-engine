require 'test_helper'

module Shipit
  class PullRequestTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
    end

    test ".request_merge! creates a record and schedule a refresh" do
      pull_request = nil
      assert_enqueued_with(job: RefreshPullRequestJob) do
        pull_request = PullRequest.request_merge!(@stack, 64)
      end
      assert_predicate pull_request, :persisted?
    end

    test ".request_merge! only track pull requests once" do
      assert_difference -> { PullRequest.count }, +1 do
        5.times { PullRequest.request_merge!(@stack, 64) }
      end
    end

    test "refresh! pulls state from GitHub" do
      pull_request = shipit_pull_requests(:shipit_fetching)

      head_sha = '64b3833d39def7ec65b57b42f496eb27ab4980b6'
      Shipit.github_api.expects(:pull_request).with(@stack.github_repo_name, pull_request.number).returns(
        stub(
          id: 4_857_578,
          url: 'https://api.github.com/repos/Shopify/shipit-engine/pulls/64',
          title: 'Great feature',
          state: 'open',
          mergeable: true,
          additions: 24,
          deletions: 5,
          head: stub(
            sha: head_sha,
          ),
        ),
      )

      author = stub(
        id: 1234,
        login: 'bob',
        name: 'Bob the Builder',
        email: 'bob@bob.com',
      )
      Shipit.github_api.expects(:commit).with(@stack.github_repo_name, head_sha).returns(
        stub(
          sha: head_sha,
          author: author,
          committer: author,
          commit: stub(
            message: 'Great feature',
            author: stub(date: 1.day.ago),
            committer: stub(date: 1.day.ago),
          ),
          stats: stub(
            additions: 24,
            deletions: 5,
          ),
        ),
      )

      Shipit.github_api.expects(:statuses).with(@stack.github_repo_name, head_sha).returns([stub(
        state: 'success',
        description: nil,
        context: 'default',
        target_url: 'http://example.com',
        created_at: 1.day.ago,
      )])

      pull_request.refresh!

      assert_predicate pull_request, :mergeable?
      assert_predicate pull_request, :pending?

      assert_not_nil pull_request.head
      assert_predicate pull_request.head, :detached?
      assert_predicate pull_request.head, :success?
    end
  end
end
