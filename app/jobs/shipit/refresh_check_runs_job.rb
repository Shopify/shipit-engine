# typed: false
module Shipit
  class RefreshCheckRunsJob < BackgroundJob
    queue_as :default

    def perform(params)
      if params[:commit_id]
        Commit.find(params[:commit_id]).refresh_check_runs!
      else
        stack = Stack.find(params[:stack_id])
        stack.commits.order(id: :desc).limit(30).each(&:refresh_check_runs!)
      end
    end
  end
end
