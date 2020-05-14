# frozen_string_literal: true
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

require 'shipit/octokit_check_runs'
require 'shipit/flock'
require 'shipit/github_app'
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
require 'shipit/github_http_cache_middleware'
require 'shipit/same_site_cookie_middleware'
require 'shipit/cast_value'
require 'shipit/line_buffer'

SafeYAML::OPTIONS[:default_mode] = :safe
SafeYAML::OPTIONS[:deserialize_symbols] = false

module Shipit
  extend self

  delegate :table_name_prefix, to: :secrets

  attr_accessor :disable_api_authentication, :timeout_exit_codes
  attr_writer :internal_hook_receivers, :task_logger, :preferred_org_emails

  self.timeout_exit_codes = [].freeze

  def authentication_disabled?
    ENV['SHIPIT_DISABLE_AUTH'].present?
  end

  def enable_samesite_middleware?
    ENV['SHIPIT_ENABLE_SAMESITE_NONE'].present?
  end

  def app_name
    @app_name ||= secrets.app_name || Rails.application.class.name.split(':').first || 'Shipit'
  end

  def redis_url
    secrets.redis_url.present? ? URI(secrets.redis_url) : nil
  end

  def redis(namespace = nil)
    @redis ||= Redis.new(
      url: redis_url.to_s.presence,
      logger: Rails.logger,
      reconnect_attempts: 3,
      reconnect_delay: 0.5,
      reconnect_delay_max: 1,
    )
    return @redis unless namespace
    Redis::Namespace.new(namespace, redis: @redis)
  end

  def github
    @github ||= GitHubApp.new(secrets.github)
  end

  def legacy_github_api
    if secrets&.github_api.present?
      @legacy_github_api ||= github.new_client(access_token: secrets.github_api['access_token'])
    end
  end

  def user
    if github.bot_login
      User.find_or_create_by_login!(github.bot_login)
    else
      AnonymousUser.new
    end
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

  def default_merge_method
    secrets.default_merge_method || 'merge'
  end

  def enforce_publish_config
    secrets.enforce_publish_config.presence
  end

  def npm_org_scope
    secrets.npm_org_scope.presence
  end

  def private_npm_registry
    secrets.private_npm_registry.presence
  end

  def github_teams
    @github_teams ||= github.oauth_teams.map { |t| Team.find_or_create_by_handle(t) }
  end

  def all_settings_present?
    @all_settings_present ||= [
      secrets.github, # TODO: handle GitHub settings
      redis_url,
      host,
    ].all?(&:present?)
  end

  def env
    { 'SHIPIT' => '1' }.merge(secrets.env || {})
  end

  def shell_paths
    [Shipit::Engine.root.join('lib', 'snippets').to_s]
  end

  def revision
    @revision ||= begin
      if revision_file.exist?
        revision_file.read
      else
        %x(git rev-parse HEAD)
      end.strip
    end
  end

  def default_inactivity_timeout
    secrets.commands_inactivity_timeout || 5.minutes.to_i
  end

  def committer_name
    secrets.committer_name.presence || app_name
  end

  def committer_email
    secrets.committer_email.presence || "#{app_name.underscore.dasherize}@#{host}"
  end

  def internal_hook_receivers
    @internal_hook_receivers ||= []
  end

  def preferred_org_emails
    @preferred_org_emails ||= []
  end

  def task_logger
    @task_logger ||= Logger.new(nil)
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
