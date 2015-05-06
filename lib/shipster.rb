require 'active_support/all'
require 'active_model_serializers'
require 'state_machines-activerecord'
require 'validate_url'
require 'responders'
require 'explicit-parameters'

require 'sass-rails'
require 'coffee-rails'
require 'jquery-rails'
require 'rails-timeago'
require 'ansi_stream'

require 'omniauth-github'

require 'pubsubstub'
require 'safe_yaml/load'
require 'securecompare'

require 'redis-objects'

require 'octokit'
require 'faraday-http-cache'

require 'shipster/engine'

require 'commands'
require 'task_commands'
require 'deploy_commands'

require 'octokit_iterator'

Dir[__dir__ + '/**/*.rb'].each { |f| require f } # TODO: do this properly

SafeYAML::OPTIONS[:default_mode] = :safe
SafeYAML::OPTIONS[:deserialize_symbols] = false

module Shipster
  extend self

  module NullSerializer
    def self.load(object)
      object
    end

    def self.dump(object)
      object
    end
  end

  def redis
    @redis ||= Redis.new(url: Rails.application.secrets.redis_url, logger: Rails.logger)
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

  def host
    secrets.host.presence || fail("Missing `host` setting in secrets.yml")
  end

  def github_required?
    !github['optional']
  end

  def github_team
    @github_team ||= github['team'] && Team.find_or_create_by_handle(github['team'])
  end

  def github_key
    github['key']
  end

  def github_secret
    github['secret']
  end

  def github
    secrets.github || {}
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
