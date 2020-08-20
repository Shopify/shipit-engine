# frozen_string_literal: true

module Shipit
  module Webhooks
    module Handlers
      module PullRequest
        class AssignedHandler < Shipit::Webhooks::Handlers::Handler
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
            return unless respond_to_assignee_change?

            pull_request.update(pull_request_attributes) if pull_request.present?
          end

          private

          def respond_to_assignee_change?
            %w[assigned unassigned].include?(params.action)
          end

          def pull_request
            @pull_request ||= Shipit::PullRequest
              .joins(:stack, stack: :repository)
              .find_by(
                number: params.number,
                stacks: {
                  repositories:
                    {
                      id: repository.id,
                    },
                }
              )
          end

          def repository
            Shipit::Repository.from_github_repo_name(params.repository.full_name) || Shipit::NullRepository.new
          end

          def pull_request_attributes
            Shipit::PullRequest.attributes_from_github(params.pull_request)
          end
        end
      end
    end
  end
end
