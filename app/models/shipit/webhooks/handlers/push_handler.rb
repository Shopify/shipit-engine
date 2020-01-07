module Shipit
  module Webhooks
    module Handlers
      class PushHandler < Handler
        params do
          requires :ref
        end
        def process
          stacks.where(branch: branch).each(&:sync_github)
        end

        private

        def branch
          params.ref.gsub('refs/heads/', '')
        end
      end
    end
  end
end
