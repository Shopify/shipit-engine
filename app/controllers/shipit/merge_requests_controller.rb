# frozen_string_literal: true

module Shipit
  class MergeRequestsController < ShipitController
    def index
      @merge_requests = stack.merge_requests.queued
    end

    def create
      if pr_number = MergeRequest.extract_number(stack, params[:number_or_url])
        merge_request = MergeRequest.request_merge!(stack, pr_number, current_user)
        flash[:success] = "Pull request ##{merge_request.number} added to the queue."
      else
        flash[:warning] = "Invalid or missing pull request number."
      end
      redirect_to(stack_merge_requests_path)
    end

    def destroy
      merge_request = stack.merge_requests.find(params[:id])
      merge_request.cancel!
      flash[:success] = 'Merge canceled'
      redirect_to(stack_merge_requests_path)
    end

    private

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
