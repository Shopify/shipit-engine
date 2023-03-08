# frozen_string_literal: true
module Shipit
  class RefreshStatusesJob < BackgroundJob
    include BackgroundJob::Unique
    on_duplicate :drop

    queue_as :default

    def perform(params)
      if params[:commit_id]
        Commit.find(params[:commit_id]).refresh_statuses!
      else
        stack = Stack.find(params[:stack_id])
        stack.commits.order(id: :desc).limit(30).each(&:refresh_statuses!)
      end
    end
  end
end
