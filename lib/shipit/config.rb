module Shipit::Config
  module NullSerializer
    def self.load(object)
      object
    end

    def self.dump(object)
      object
    end
  end

  def github_api
    @github_api ||= begin
      credentials = Rails.application.secrets.github_credentials || {}
      client = Octokit::Client.new(credentials.symbolize_keys)
      client.middleware.use(
        Faraday::HttpCache,
        shared_cache: false,
        store: Rails.cache,
        logger: Rails.logger,
        serializer: NullSerializer,
      )
      client
    end
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

  def bugsnag_api_key
    # TODO: Update cookbooks and get rid of this key
    secrets.bugsnag_api_key.presence || '8f5ef714c28f7ea7b5c1fde664d3dc7a'
  end

  protected

  def revision_file
    Rails.root.join('REVISION')
  end

  def secrets
    Rails.application.secrets
  end
end
