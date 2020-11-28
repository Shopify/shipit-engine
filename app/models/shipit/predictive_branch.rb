# frozen_string_literal: true

module Shipit
  class PredictiveBranch < Task

      has_many :predictive_release, dependent: :destroy, inverse_of: :task, foreign_key: :task_id

      after_commit :broadcast_update

      delegate :broadcast_update, to: :stack

      def async_refresh_deployed_revision

      end


      def async_update_estimated_deploy_duration

      end

      def working_directory
        File.join(stack.builds_path, id.to_s)
      end

  end
end
