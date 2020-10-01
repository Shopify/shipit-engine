# frozen_string_literal: true

require "test_helper"

module Shipit
  class PullRequestTest < ActiveSupport::TestCase
    test "github_pull_request= parses into a a Shipit::PullRequest" do
      github_pull_request = resource(
        {
          url: "https://api.github.com/repos/Codertocat/Hello-World/pulls/2",
          id: 279147437,
          number: 2,
          state: "open",
          additions: 100,
          deletions: 101,
          title: "Update the README with new information.",
          head: {
            sha: "ec26c3e57ca3a959ca5aad62de7213c562f8c821",
          },
          user: {
            login: "Codertocat",
          },
          assignees: [
            {
              login: "bob",
            },
          ],
          labels: [
            {
              name: "deploy",
            },
          ],
        }
      )
      stack = shipit_stacks(:review_stack)
      pull_request = stack.pull_request

      stack.pull_request.github_pull_request = github_pull_request

      assert_equal 279147437, pull_request.github_id
      assert_equal 2, pull_request.number
      assert_equal "https://api.github.com/repos/Codertocat/Hello-World/pulls/2", pull_request.api_url
      assert_equal "Update the README with new information.", pull_request.title
      assert_equal "open", pull_request.state
      assert_equal 100, pull_request.additions
      assert_equal 101, pull_request.deletions
      assert_equal shipit_users(:codertocat), pull_request.user
      assert_equal [shipit_users(:bob)], pull_request.assignees
      assert_equal ["deploy"], pull_request.labels
    end
  end
end
