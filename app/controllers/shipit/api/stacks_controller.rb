# frozen_string_literal: true

module Shipit
  module Api
    class StacksController < BaseController
      require_permission :read, :stack, only: %i[index show]
      require_permission :write, :stack, only: %i[create update destroy]

      params do
        accepts :repo_owner, String
        accepts :repo_name, String
      end
      def index
        @stacks = stacks
        if params[:repo_owner] && params[:repo_name]
          full_repo_name = [repo_owner, repo_name].join('/')
          @stacks = if (repository = Repository.from_github_repo_name(full_repo_name))
                      stacks.where(repository:)
                    else
                      Stack.none
                    end
        end
        render_resources(@stacks)
      end

      params do
        requires :repo_owner, String
        requires :repo_name, String
        accepts :environment, String
        accepts :branch, String
        accepts :deploy_url, String, allow_nil: true
        accepts :ignore_ci, Boolean
        accepts :merge_queue_enabled, Boolean
        accepts :continuous_deployment, Boolean
      end
      def create
        stack = Stack.new(create_params)
        stack.repository = repository
        stack.save
        render_resource(stack)
      end

      params do
        accepts :environment, String
        accepts :branch, String
        accepts :deploy_url, String, allow_nil: true
        accepts :ignore_ci, Boolean
        accepts :merge_queue_enabled, Boolean
        accepts :continuous_deployment, Boolean
        accepts :archived, Boolean
      end
      def update
        stack.update(update_params)

        update_archived

        render_resource(stack)
      end

      def show
        render_resource(stack)
      end

      def destroy
        stack.schedule_for_destroy!
        head(:accepted)
      end

      def refresh
        RefreshStatusesJob.perform_later(stack_id: stack.id)
        RefreshCheckRunsJob.perform_later(stack_id: stack.id)
        GithubSyncJob.perform_later(stack_id: stack.id)
        render_resource(stack, status: :accepted)
      end

      private

      def create_params
        params.reject { |key, _| %i[repo_owner repo_name].include?(key) }
      end

      def stack
        @stack ||= stacks.from_param!(params[:id])
      end

      def update_archived
        return unless key?(:archived)

        if params[:archived]
          stack.archive!(nil)
        elsif stack.archived?
          stack.unarchive!
        end
      end

      def key?(key)
        params.to_h.key?(key)
      end

      def update_params
        params.select do |key, _|
          %i[environment branch deploy_url ignore_ci merge_queue_enabled continuous_deployment].include?(key)
        end
      end

      def repository
        @repository ||= Repository.find_or_create_by(owner: repo_owner, name: repo_name)
      end

      def repo_owner
        params[:repo_owner]
      end

      def repo_name
        params[:repo_name]
      end
    end
  end
end
