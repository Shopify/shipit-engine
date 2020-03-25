# typed: true
module Shipit
  module MergeStatusHelper
    def display_commit_count_warning?(commits)
      commits > 4 && @stack.merge_queue_enabled?
    end
  end
end
