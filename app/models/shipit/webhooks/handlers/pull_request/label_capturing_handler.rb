# frozen_string_literal: true

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class LabelCapturingHandler < Shipit::Webhooks::Handlers::Handler
          params do
            requires :action, String
            requires :number, Integer
            requires :pull_request do
              requires :id, Integer
              requires :number, Integer
              requires :url, String
              requires :title, String
              requires :state, String
              requires :additions, Integer
              requires :deletions, Integer
              requires :head do
                requires :sha, String
                requires :ref, String
              end
              requires :user do
                requires :login, String
              end
              requires :assignees, Array do
                requires :login, String
              end
              requires :labels, Array do
                requires :name, String
              end
            end
            requires :repository do
              requires :full_name, String
            end
            requires :sender do
              requires :login, String
            end
          end

          def process
            return unless capture_labels?

            capture_labels

            stack
          end

          private

          def capture_labels?
            opened_active_stack? ||
              labeled_active_stack? ||
              unlabeled_active_stack? ||
              reopened_active_stack?
          end

          def opened_active_stack?
            opened? && stack.present?
          end

          def labeled_active_stack?
            labeled? && stack.present? && !stack.archived?
          end

          def unlabeled_active_stack?
            unlabeled? && stack.present? && !stack.archived?
          end

          def reopened_active_stack?
            reopened? && stack.present? && !stack.archived?
          end

          def opened?
            action == "opened"
          end

          def labeled?
            action == "labeled"
          end

          def unlabeled?
            action == "unlabeled"
          end

          def reopened?
            action == "reopened"
          end

          def action
            params.action
          end

          def pull_request
            params.pull_request
          end

          def capture_labels
            return unless pull_request = stack.pull_request

            pull_request.update!(labels: params.pull_request.labels.map(&:name))
          end

          def review_stack
            @review_stack ||=
              Shipit::Webhooks::Handlers::PullRequest::ReviewStackAdapter
                .new(params, scope: repository.review_stacks)
          end

          def repository
            @repository ||=
              Shipit::Repository
                .from_github_repo_name(params.repository.full_name) || NullRepository.new
          end

          def stack
            @stack ||= review_stack.stack
          end

          def labels
            Array.new(pull_request.labels).map(&:name)
          end
        end
      end
    end
  end
end
