# frozen_string_literal: true
module Shipit
  class MergeStatusController < ShipitController
    skip_authentication only: %i(check show)

    etag { cache_seed }
    layout 'merge_status'

    def show
      response.headers['X-Frame-Options'] = 'ALLOWALL'
      response.headers['Vary'] = 'X-Requested-With'

      if stack
        return render('logged_out') unless current_user.logged_in?
        if stale?(last_modified: [stack.updated_at, merge_request.updated_at].max, template: false)
          render(stack_status, layout: !request.xhr?)
        end
      else
        render(html: '')
      end
    rescue ArgumentError
      render(html: '')
    end

    def enqueue
      MergeRequest.request_merge!(stack, params[:number], current_user)
      render(stack_status, layout: !request.xhr?)
    end

    def dequeue
      if merge_request = stack.merge_requests.find_by_number(params[:number])
        merge_request.cancel! if merge_request.waiting?
      end
      render(stack_status, layout: !request.xhr?)
    end

    def check
      respond_to do |format|
        format.html do
          if stack_status == 'success'
            render plain: 'ok'
          else
            render plain: stack_status, status: 503
          end
        end
        format.json { render json: { stack_status: stack_status } }
      end
    end

    private

    def cache_seed
      "#{request.xhr? ? 'partial' : 'full'}-#{Shipit.revision}"
    end

    def stack_status
      @stack_status ||= stack.merge_status(backlog_leniency_factor: 1.0)
    end

    def stack
      @stack ||= if params[:stack_id]
        Stack.from_param!(params[:stack_id])
      else
        # Null ordering is inconsistent across DBMS's, this case statement is ugly but supported universally
        scope = Stack.order(Arel.sql('CASE WHEN locked_since IS NULL THEN 1 ELSE 0 END, locked_since'))
          .order(merge_queue_enabled: :desc, id: :asc).includes(:repository).where(
            repositories: {
              owner: referrer_parser.repo_owner,
              name: referrer_parser.repo_name,
            },
          )
        scope = if params[:branch]
          scope.where(branch: params[:branch])
        else
          scope.where(environment: 'production')
        end
        scope.first
      end
    end

    def referrer_parser
      @referrer_parser ||= ReferrerParser.new(params[:referrer])
    end

    def merge_request
      return @merge_request if defined?(@merge_request)
      @merge_request = pull_request_number && stack.merge_requests.find_by_number(pull_request_number)
      @merge_request ||= UnknownMergeRequest.new
    end

    def pull_request_number
      return @pull_request_number if defined?(@pull_request_number)
      @pull_request_number = referrer_parser.pull_request_number
    end

    def queue_enabled?
      stack.merge_queue_enabled? && pull_request_number
    end

    helper_method :pull_request_number
    helper_method :merge_request
    helper_method :queue_enabled?
    helper_method :stack
    helper_method :stack_status

    # FIXME: for some reason if invoked in the view, those path helpers will link to /events?...
    helper_method :enqueue_merge_request_path
    helper_method :dequeue_merge_request_path

    class ReferrerParser
      URL_PATTERN = %r{\Ahttps://github\.com/([^/]+)/([^/]+)/pull/(\d+)}

      attr_reader :repo_owner, :repo_name, :pull_request_number

      def initialize(referrer)
        if (match_info = URL_PATTERN.match(referrer.to_s))
          @repo_owner = match_info[1].downcase
          @repo_name = match_info[2].downcase
          @pull_request_number = match_info[3].to_i
        else
          raise ArgumentError, "Invalid referrer: #{referrer.inspect}"
        end
      end
    end

    class UnknownMergeRequest
      attr_reader :updated_at

      def initialize
        @updated_at = Time.at(0).utc
      end

      def waiting?
        false
      end
    end
  end
end
