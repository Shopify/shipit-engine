require 'octokit'

# https://github.com/octokit/octokit.rb/pull/1006
if Octokit::VERSION >= '5'
  raise 'This patch should be removed'
else
  module Octokit
    module Connection
      protected

      def request(method, path, data, options = {})
        if data.is_a?(Hash)
          options[:query] = data.delete(:query) || {}
          options[:headers] = data.delete(:headers) || {}
          if accept = data.delete(:accept)
            options[:headers][:accept] = accept
          end
        end

        @last_response = response = agent.call(method, Addressable::URI.parse(path.to_s).normalize.to_s, data, options)
        response.data
      end
    end
  end
end
