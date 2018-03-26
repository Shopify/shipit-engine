require 'active_support/all'
require 'active_model_serializers'
require 'state_machines-activerecord'
require 'validate_url'
require 'responders'
require 'explicit-parameters'
require 'attr_encrypted'

require 'sass-rails'
require 'coffee-rails'
require 'jquery-rails'
require 'rails-timeago'
require 'lodash-rails'
require 'ansi_stream'
require 'autoprefixer-rails'
require 'rails_autolink'
require 'gemoji'

require 'omniauth-github'

require 'pubsubstub'
require 'safe_yaml/load'
require 'securecompare'

require 'redis-objects'
require 'redis-namespace'

require 'octokit'
require 'faraday-http-cache'

require 'shipit/version'

require 'shipit/template_renderer_extension'

require 'shipit/paginator'
require 'shipit/null_serializer'
require 'shipit/csv_serializer'
require 'shipit/octokit_iterator'
require 'shipit/first_parent_commits_iterator'
require 'shipit/simple_message_verifier'
require 'shipit/command'
require 'shipit/commands'
require 'shipit/stack_commands'
require 'shipit/task_commands'
require 'shipit/deploy_commands'
require 'shipit/rollback_commands'
require 'shipit/environment_variables'
require 'shipit/stat'
require 'shipit/strip_cache_control'

SafeYAML::OPTIONS[:default_mode] = :safe
SafeYAML::OPTIONS[:deserialize_symbols] = false

module Shipit
  extend self

  delegate :table_name_prefix, to: :secrets

  attr_accessor :disable_api_authentication, :timeout_exit_codes
  attr_writer :automatically_prepend_bundle_exec

  self.timeout_exit_codes = [].freeze

  def app_name
    @app_name ||= secrets.app_name || Rails.application.class.name.split(':').first || 'Shipit'
  end

  def redis_url
    secrets.redis_url.present? ? URI(secrets.redis_url) : nil
  end

  def redis(namespace = nil)
    @redis ||= Redis.new(url: redis_url.to_s.presence, logger: Rails.logger)
    return @redis unless namespace
    Redis::Namespace.new(namespace, redis: @redis)
  end

  def github_domain
    @github_domain ||= secrets.github_domain.presence || 'github.com'.freeze
  end

  def github_enterprise?
    github_domain != 'github.com'
  end

  def github_url(path = nil)
    @github_url ||= "https://#{github_domain}".freeze
    path ? File.join(@github_url, path) : @github_url
  end

  def github_api_endpoint
    github_url('/api/v3/') if github_enterprise?
  end

  def user
    if github_api.login
      User.find_or_create_by_login!(github_api.login)
    else
      AnonymousUser.new
    end
  end

  def github_api
    @github_api ||= begin
      client = Octokit::Client.new(github_api_credentials)
      client.middleware = new_faraday_stack
      client
    end
  end

  def new_faraday_stack
    Faraday::RackBuilder.new do |builder|
      builder.use(
        Faraday::HttpCache,
        shared_cache: false,
        store: Rails.cache,
        logger: Rails.logger,
        serializer: NullSerializer,
      )
      builder.use StripCacheControl
      builder.use Octokit::Response::RaiseError
      builder.adapter Faraday.default_adapter
      yield builder if block_given?
    end
  end

  def github_api_credentials
    {api_endpoint: github_api_endpoint}.merge((Rails.application.secrets.github_api || {}).symbolize_keys)
  end

  def api_clients_secret
    secrets.api_clients_secret.presence || secrets.secret_key_base
  end

  def user_access_tokens_key
    (secrets.user_access_tokens_key.presence || secrets.secret_key_base).byteslice(0, 32)
  end

  def host
    secrets.host.presence
  end

  def enforce_publish_config
    secrets.enforce_publish_config.presence ? secrets.enforce_publish_config : nil
  end

  def private_npm_registry
    secrets.private_npm_registry.presence ? secrets.private_npm_registry : nil
  end

  def github_teams
    @github_teams ||= github_teams_handles.map { |t| Team.find_or_create_by_handle(t) }
  end

  def github_teams_handles
    (Array(github_oauth_credentials['team']) + Array(github_oauth_credentials['teams'])).sort.uniq
  end

  def github_oauth_id
    github_oauth_credentials['id']
  end

  def github_oauth_secret
    github_oauth_credentials['secret']
  end

  def github_oauth_credentials
    (secrets.github_oauth || {}).to_h.stringify_keys
  end

  def github_oauth_options
    return {} unless github_enterprise?
    {
      site: github_api_endpoint,
      authorize_url: github_url('/login/oauth/authorize'),
      token_url: github_url('/login/oauth/access_token'),
    }
  end

  def all_settings_present?
    @all_settings_present ||= [
      github_oauth_id,
      github_oauth_secret,
      github_api_credentials,
      redis_url,
      host,
    ].all?(&:present?)
  end

  def env
    {'SHIPIT' => '1'}.merge(secrets.env || {})
  end

  def shell_paths
    [Shipit::Engine.root.join('lib', 'snippets').to_s]
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

  def feature_bootstrap?
    secrets.features.try!(:include?, 'bootstrap')
  end

  def bootstrap_view_path
    @bootstrap_view_path ||= Engine.root.join('app/views/bootstrap')
  end

  def default_inactivity_timeout
    secrets.commands_inactivity_timeout || 5.minutes.to_i
  end

  def automatically_prepend_bundle_exec
    unless defined?(@automatically_prepend_bundle_exec)
      ActiveSupport::Deprecation.warn(
        'Automatically prepending `bundle exec` will be removed in a future version of Shipit, '\
        'set `Shipit.automatically_prepend_bundle_exec = false` to test the new behaviour.',
      )
      @automatically_prepend_bundle_exec = true
    end
    @automatically_prepend_bundle_exec
  end

  protected

  def revision_file
    Rails.root.join('REVISION')
  end

  def secrets
    Rails.application.secrets
  end
end

require 'shipit/engine'
