module Shipit::Config
  def github_api
    credentials = Rails.application.secrets.github_credentials || {}
    @github_api ||= Octokit::Client.new(credentials.symbolize_keys)
  end
end
