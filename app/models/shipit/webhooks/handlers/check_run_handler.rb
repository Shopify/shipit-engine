# frozen_string_literal: true
module Shipit
  module Webhooks
    module Handlers
      class CheckRunHandler < Handler
        params do
          requires :check_run do
            requires :head_sha, String
            requires :id, String
            requires :output do
              requires :title, String
            end

            accepts :name, String
            accepts :conclusion, String
            accepts :started_at, String
            accepts :completed_at, String
            accepts :details_url, String
            accepts :html_url, String
          end
        end
        def process
          Commit.where(sha: params.check_run.head_sha).each do |commit|
            commit.create_or_update_check_run_from_github!(params.check_run)
          end
        end
      end
    end
  end
end
