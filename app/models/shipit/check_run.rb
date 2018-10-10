module Shipit
  class CheckRun < ApplicationRecord
    CONCLUSIONS = %w(success failure neutral cancelled timed_out action_required).freeze
    include DeferredTouch
    include Status::Common

    belongs_to :stack, required: true
    belongs_to :commit, required: true

    deferred_touch commit: :updated_at

    validates :conclusion, inclusion: {in: CONCLUSIONS, allow_nil: true}

    class << self
      def create_or_update_by!(selector:, attributes: {})
        create!(selector.merge(attributes))
      rescue ActiveRecord::RecordNotUnique
        record = find_by!(selector)
        record.update!(attributes)
        record
      end

      def create_or_update_from_github!(stack_id, github_check_run)
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
          },
        )
      end
    end

    def state
      case conclusion
      when nil, 'action_required'
        'pending'
      when 'success', 'neutral'
        'success'
      when 'failure', 'cancelled'
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
  end
end
