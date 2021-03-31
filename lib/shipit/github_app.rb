# frozen_string_literal: true
module Shipit
  class GitHubApp
    include Mutex_m

    class Token
      class << self
        def from_github(github_response)
          new(github_response.token, github_response.expires_at)
        end
      end

      attr_reader :expires_at, :refresh_at

      def to_s
        @token
      end

      def initialize(token, expires_at)
        @token = token
        @expires_at = expires_at

        # This needs to be lower than the token's lifetime, but higher than the cache expiry setting.
        @refresh_at = expires_at - GITHUB_TOKEN_REFRESH_WINDOW
      end

      def blank?
        # Old tokens missing @refresh_at may be used upon deploy, so we should auto-correct for now.
        # TODO: Remove this assignment at a later date.
        @refresh_at ||= @expires_at - GITHUB_TOKEN_REFRESH_WINDOW
        @refresh_at.past?
      end
    end

    DOMAIN = 'github.com'
    AuthenticationFailed = Class.new(StandardError)
    API_STATUS_ID = 'brv1bkgrwx7q'

    GITHUB_EXPECTED_TOKEN_LIFETIME = 60.minutes
    GITHUB_TOKEN_RAILS_CACHE_LIFETIME = 50.minutes
    GITHUB_TOKEN_REFRESH_WINDOW = GITHUB_EXPECTED_TOKEN_LIFETIME - GITHUB_TOKEN_RAILS_CACHE_LIFETIME - 2.minutes

    attr_reader :oauth_teams, :domain, :bot_login

    def initialize(organization, config)
      super()
      @organization = organization
      @config = (config || {}).with_indifferent_access
      @domain = @config[:domain] || DOMAIN
      @webhook_secret = @config[:webhook_secret].presence
      @bot_login = @config[:bot_login]

      oauth = (@config[:oauth] || {}).with_indifferent_access
      @oauth_id = oauth[:id]
      @oauth_secret = oauth[:secret]
      @oauth_teams = Array.wrap(oauth[:teams])
    end

    def login
      raise NotImplementedError, 'Handle App login / user'
    end

    def api
      client = (Thread.current[:github_client] ||= new_client(access_token: token))
      if client.access_token != token
        client.access_token = token
      end
      client
    end

    def api_status
      conn = Faraday.new(url: 'https://www.githubstatus.com')
      response = conn.get('/api/v2/components.json')
      parsed = JSON.parse(response.body, symbolize_names: true)
      parsed[:components].find { |c| c[:id] == API_STATUS_ID }
    end

    def verify_webhook_signature(signature, message)
      return true unless webhook_secret

      algorithm, signature = signature.split("=", 2)
      return false unless algorithm == 'sha1'

      SecureCompare.secure_compare(signature, OpenSSL::HMAC.hexdigest(algorithm, webhook_secret, message))
    end

    def token
      return 't0kEn' if Rails.env.test? # TODO: figure out something cleaner
      return unless private_key && app_id && installation_id

      @token = @token.presence || synchronize { @token.presence || fetch_new_token }
      @token.to_s
    end

    def fetch_new_token
      cache_key = @organization.nil? ? '' : "#{@organization.downcase}:"
      # Rails can add 5 minutes to the cache entry expiration time when any TTL is provided,
      # so our TTL setting can be lower, and TTL + expires_in should be lower than the GitHub token expiration.
      Rails.cache.fetch(
        "github:integration:#{cache_key}access-token",
        expires_in: GITHUB_TOKEN_RAILS_CACHE_LIFETIME,
        race_condition_ttl: 4.minutes,
      ) do
        response = new_client(bearer_token: authentication_payload).create_app_installation_access_token(
          installation_id,
          accept: 'application/vnd.github.machine-man-preview+json',
        )
        token = Token.from_github(response)
        raise AuthenticationFailed if token.blank?
        Rails.logger.info("Created GitHub access token ending #{token.to_s[-5..-1]}, expires at #{token.expires_at}"\
          " and will be refreshed at #{token&.refresh_at}")
        token
      end
    end

    def oauth?
      oauth_id.present? && oauth_secret.present?
    end

    def oauth_config
      options = {}
      if enterprise?
        options = {
          site: api_endpoint,
          authorize_url: url('/login/oauth/authorize'),
          token_url: url('/login/oauth/access_token'),
        }
      end

      [
        oauth_id,
        oauth_secret,
        client_options: options,
      ]
    end

    def url(*path)
      @url ||= "https://#{domain}"
      path.empty? ? @url : File.join(@url, *path.map(&:to_s))
    end

    def api_endpoint
      url('/api/v3/') if enterprise?
    end

    def web_endpoint
      url if enterprise?
    end

    def enterprise?
      domain != DOMAIN
    end

    def new_client(options = {})
      if enterprise?
        options = options.reverse_merge(
          api_endpoint: api_endpoint,
          web_endpoint: web_endpoint,
        )
      end
      client = Octokit::Client.new(options)
      client.middleware = faraday_stack
      client
    end

    private

    attr_reader :webhook_secret, :oauth_id, :oauth_secret

    def faraday_stack
      @faraday_stack ||= Faraday::RackBuilder.new do |builder|
        builder.use(
          Faraday::HttpCache,
          shared_cache: false,
          store: Rails.cache,
          logger: Rails.logger,
          serializer: NullSerializer,
        )
        builder.use(GitHubHTTPCacheMiddleware)
        builder.use(Octokit::Response::RaiseError)
        builder.adapter(Faraday.default_adapter)
      end
    end

    def app_id
      @config.fetch(:app_id)
    end

    def installation_id
      @config.fetch(:installation_id)
    end

    def private_key
      @config.fetch(:private_key)
    end

    def authentication_payload
      payload = {
        iat: Time.now.to_i,
        exp: 10.minutes.from_now.to_i,
        iss: app_id,
      }
      key = OpenSSL::PKey::RSA.new(private_key)
      JWT.encode(payload, key, 'RS256')
    end
  end
end
