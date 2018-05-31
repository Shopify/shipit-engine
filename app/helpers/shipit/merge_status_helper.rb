module Shipit
  module MergeStatusHelper
    def too_many_commits?(commits)
      commits > 4
    end
  end
end
