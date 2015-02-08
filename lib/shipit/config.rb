module Shipit::Config
  def github_api
    credentials = Rails.application.secrets.github_credentials || {}
    @github_api ||= Octokit::Client.new(credentials.symbolize_keys)
  end

  def api_clients_secret
    Rails.application.secrets.api_clients_secret || ''
  end

  delegate :authentication, :github, :host, to: :secrets

  def github_required?
    github && !github['optional']
  end

  def github_key
    github && github['key']
  end

  def github_secret
    github && github['secret']
  end

  def authentication_settings
    parameters = Array(authentication['parameters'] || authentication['options'])
    [authentication['provider'], *parameters]
  end

  def extra_env
    secrets.env || {}
  end

  def revision
    @revision ||= begin
      if revision_file.exist?
        revision_file.read
      else
        `git rev-parse HEAD`
      end.strip
    end
  end

  protected

  def revision_file
    Rails.root.join('REVISION')
  end

  def secrets
    Rails.application.secrets
  end
end
