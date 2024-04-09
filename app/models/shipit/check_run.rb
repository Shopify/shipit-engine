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

        # Checkruns can jump between states and conclusions, and the github timestamps are low precision and unreliable.
        # Since there's a conflict and the webhook seems older, enqueue a refresh.
        # Persist the received data anyways, in case it is now the canonical data on GitHub despite the timestamp.
        if attributes[:conclusion] != record.conclusion && record.newer_than_webhook?(attributes)
          Rails.logger.warn(
            "Conflicting stale checkrun received. Checkrun id: #{selector[:github_id]}, Details: #{attributes}"
          )
          RefreshCheckRunsJob.set(wait: CHECK_RUN_REFRESH_DELAY).perform_later(commit_id: record.commit_id)
        end

        record.update!(attributes)
        record
      end

      def create_or_update_from_github!(stack_id, github_check_run)
        checkrun_date = parse_newest_date(github_check_run)

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
            github_updated_at: checkrun_date,
          },
        )
      end

      def parse_newest_date(github_check_run)
        started_at = github_check_run.started_at
        completed_at = github_check_run.completed_at

        started_at_date = Time.parse(started_at.to_s) if started_at
        completed_at_date = Time.parse(completed_at.to_s) if completed_at

        [started_at_date, completed_at_date].compact.max
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

    def newer_than_webhook?(webhook_attributes)
      github_updated_at && github_updated_at >= webhook_attributes[:github_updated_at]
    end

    private

    def enable_ci_on_stack
      commit.stack.enable_ci!
    end
  end
end
