# frozen_string_literal: true
module Shipit
  class CheckRun < ApplicationRecord
    CONCLUSIONS = %w(success failure neutral cancelled timed_out action_required stale skipped).freeze
    include DeferredTouch
    include Status::Common

    CHECK_RUN_REFRESH_DELAY = 5.seconds

    belongs_to :stack, required: true
    belongs_to :commit, required: true

    deferred_touch commit: :updated_at

    validates :conclusion, inclusion: { in: CONCLUSIONS, allow_nil: true }

    after_create :enable_ci_on_stack

    class << self
      def create_or_update_by!(selector:, attributes: {})
        create!(selector.merge(attributes))
      rescue ActiveRecord::RecordNotUnique
        record = find_by!(selector)

        if record.github_updated_at < attributes[:github_updated_at]
          record.update!(attributes)
        elsif attributes[:conclusion] != record.conclusion
          Rails.logger.warn(
            "Conflicting stale checkrun received. Checkrun id: #{selector[:github_id]}, Details: #{attributes}"
          )
          RefreshCheckRunsJob.set(wait: CHECK_RUN_REFRESH_DELAY).perform_later(commit_id: record.commit_id)
        end

        record
      end

      def create_or_update_from_github!(stack_id, github_check_run)
        checkrun_date = github_check_run.completed_at&.to_s || github_check_run.started_at&.to_s

        unless checkrun_date
          Rails.logger.warn("No valid timestamp found in checkrun data. Checkrun id: #{github_check_run.id}.")
          RefreshCheckRunsJob.set(wait: CHECK_RUN_REFRESH_DELAY).perform_later(stack_id: stack_id)
          return
        end

        create_or_update_by!(
          selector: {
            github_id: github_check_run.id,
          },
          attributes: {
            stack_id: stack_id,
            name: github_check_run.name,
            conclusion: github_check_run.conclusion,
            title: github_check_run.output.title.to_s.truncate(1_000),
            details_url: github_check_run.details_url,
            html_url: github_check_run.html_url,
            github_updated_at: Time.parse(checkrun_date),
          },
        )
      end
    end

    def state
      case conclusion
      when nil, 'action_required'
        'pending'
      when 'success', 'neutral', 'skipped'
        'success'
      when 'failure', 'cancelled', 'stale'
        'failure'
      when 'timed_out'
        'error'
      else
        'unknown'
      end
    end

    def context
      name
    end

    def target_url
      html_url
    end

    def description
      title
    end

    def to_partial_path
      'shipit/statuses/status'
    end

    private

    def enable_ci_on_stack
      commit.stack.enable_ci!
    end
  end
end
