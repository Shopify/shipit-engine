# frozen_string_literal: true
module Shipit
  module Api
    class StacksController < BaseController
      require_permission :read, :stack, only: %i(index show)
      require_permission :write, :stack, only: %i(create update destroy)

      params do
        accepts :repo_owner, String
        accepts :repo_name, String
      end
      def index
        @stacks = stacks
        if params[:repo_owner] && params[:repo_name]
          full_repo_name = [repo_owner, repo_name].join('/')
          @stacks = if (repository = Repository.from_github_repo_name(full_repo_name))
            stacks.where(repository: repository)
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
        accepts :deploy_url, String
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
        accepts :branch, String
        accepts :deploy_url, String
        accepts :ignore_ci, Boolean
        accepts :merge_queue_enabled, Boolean
        accepts :continuous_deployment, Boolean
      end
      def update
        stack.update(params)
        render_resource(stack)
      end

      def show
        render_resource(stack)
      end

      def destroy
        stack.schedule_for_destroy!
        head(:accepted)
      end

      private

      def create_params
        params.reject { |key, _| %i(repo_owner repo_name).include?(key) }
      end

      def stack
        @stack ||= stacks.from_param!(params[:id])
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
