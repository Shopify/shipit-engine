# frozen_string_literal: true

module Shipit
  class CiJobsStatus < Record
    belongs_to :predictive_build, optional: true
    belongs_to :predictive_branch, optional: true

    state_machine :status, initial: :running do
      state :running
      state :failed
      state :aborted
      state :completed

      event :running do
        transition any => :running
      end

      event :failed do
        transition any => :failed
      end

      event :aborted do
        transition any => :aborted
      end

      event :completed do
        transition any => :completed
      end

    end

    def update_status(status_name)
      case status_name
      when :running
        running
        return
      when :failed
        failed
        return
      when :aborted
        aborted
        return
      when :success, :completed
        completed
        return
      end
    end

  end
end
