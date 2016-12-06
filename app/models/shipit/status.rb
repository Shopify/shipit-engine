module Shipit
  class Status < ActiveRecord::Base
    STATES = %w(pending success failure error).freeze
    enum state: STATES.zip(STATES).to_h

    belongs_to :stack, touch: true, required: true
    belongs_to :commit, touch: true, required: true

    validates :state, inclusion: {in: STATES, allow_blank: true}, presence: true

    after_create :enable_ci_on_stack
    after_commit :schedule_continuous_delivery, :broadcast_update, on: :create
    after_commit :touch_commit

    delegate :broadcast_update, to: :commit

    class << self
      def replicate_from_github!(stack_id, github_status)
        find_or_create_by!(
          stack_id: stack_id,
          state: github_status.state,
          description: github_status.description,
          target_url: github_status.target_url,
          context: github_status.context,
          created_at: github_status.created_at,
        )
      end
    end

    def unknown?
      false
    end

    def ignored?
      stack.soft_failing_statuses.include?(context)
    end

    def group?
      false
    end

    def simple_state
      state == 'error' ? 'failure' : state
    end

    private

    def enable_ci_on_stack
      commit.stack.enable_ci!
    end

    def touch_commit
      commit.touch
    end

    def schedule_continuous_delivery
      commit.schedule_continuous_delivery
    end
  end
end
