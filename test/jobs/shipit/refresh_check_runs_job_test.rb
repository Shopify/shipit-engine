# frozen_string_literal: true

require 'test_helper'

module Shipit
  class RefreshCheckRunsJobTest < ActiveSupport::TestCase
    test "#perform backs off GitHub server errors" do
      Commit.any_instance.stubs(:refresh_check_runs!).raises(Octokit::InternalServerError)
      job = RefreshCheckRunsJob.new(commit_id: shipit_commits(:first).id)
      job.exception_executions = { "[Octokit::ServerError]" => 1 }

      freeze_time do
        retry_time = ->(at) { (18.seconds.from_now..20.4.seconds.from_now).cover?(at) }
        assert_enqueued_with(job: RefreshCheckRunsJob, at: retry_time) { job.perform_now }
      end
    end
  end
end
