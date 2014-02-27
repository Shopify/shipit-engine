module Shipit::Config
  def github_api
    @github_api ||= Octokit::Client.new(:access_token => Rails.application.secrets.github_api_token)
  end
end
