module Shipit::Config
  def github_api
    credentials = Rails.application.secrets.github_credentials || {}
    @github_api ||= Octokit::Client.new(credentials.symbolize_keys)
  end

  def ejson
    @ejson ||= EJSON.new(
      Rails.root.join('config/ejson-publickey.pem').to_s,
      Rails.root.join('config/ejson-privatekey.pem').to_s,
    )
  end

end
