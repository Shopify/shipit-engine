# frozen_string_literal: true
require 'prometheus/client'

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

      after_transition :running => %i(failed aborted completed) do |ci_jobs_status|
        ci_jobs_status.set_metrics
      end
    end

    def set_metrics
      registry = Prometheus::Client.registry
      if predictive_build.present?
        pipeline = predictive_build.pipeline.id.to_s
        stack_name = predictive_build.pipeline.name
      elsif predictive_branch.present?
        pipeline = predictive_branch.predictive_build.pipeline.id.to_s
        stack_name = predictive_branch.stack.repository.full_name
      else
        pipeline = 'unknown'
        stack_name = 'unknown'
      end
      labels = {pipeline: pipeline, stack: stack_name, type: name, status: status.to_s, executor: 'External'}
      seconds = (updated_at - created_at).to_i
      shipit_task_count = registry.get(:shipit_task_count)
      shipit_task_count.increment(labels: labels)
      shipit_task_duration_seconds_sum = registry.get(:shipit_task_duration_seconds_sum)
      shipit_task_duration_seconds_sum.increment(by: seconds, labels: labels)
    rescue Exception => e
      puts "Shipit::CiJobsStatus#set_metrics - Error: #{e.message}"
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
