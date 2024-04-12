# frozen_string_literal: true
module Shipit
  class RefreshCheckRunsJob < BackgroundJob
    queue_as :default

    def perform(params)
      if params[:commit_id]
        Commit.find(params[:commit_id]).refresh_check_runs!
      else
        stack = Stack.find(params[:stack_id])
        stack.commits.order(id: :desc).limit(30).each do |commit|
          RefreshCheckRunsJob.perform_later(commit_id: commit.id)
        end
      end
    end
  end
end
