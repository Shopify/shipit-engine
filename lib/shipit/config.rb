module Shipit::Config
  def github_api
    credentials = Rails.application.secrets.github_credentials || {}
    @github_api ||= Octokit::Client.new(credentials.symbolize_keys)
  end

  def flowdock_api(status)
    address = (status == :success) ? 'gaurav+pass@shopify.com' : 'gaurav+fail@shopify.com'

    Flowdock::Flow.new \
      api_token: Rails.application.secrets.flowdock_api['api_token'],
      source: "shipit",
      from: {
        name: 'Shipit',
        address: address
      }
  end
end
