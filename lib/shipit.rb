# frozen_string_literal: true

require 'active_support/all'
require 'active_model_serializers'
require 'state_machines-activerecord'
require 'validate_url'
require 'responders'
require 'explicit-parameters'
require 'paquito'

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
require 'shipit/review_stack_commands'
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

  GithubOrganizationUnknown = Class.new(StandardError)
  TOP_LEVEL_GH_KEYS = [:app_id, :installation_id, :webhook_secret, :private_key, :oauth, :domain].freeze

  delegate :table_name_prefix, to: :secrets

  attr_accessor :disable_api_authentication, :timeout_exit_codes, :deployment_checks, :respect_bare_shipit_file,
                :database_serializer
  attr_writer(
    :internal_hook_receivers,
    :preferred_org_emails,
    :task_execution_strategy,
    :task_logger,
    :use_git_askpass
  )

  def task_execution_strategy
    @task_execution_strategy ||= Shipit::TaskExecutionStrategy::Default
  end

  self.timeout_exit_codes = [].freeze
  self.respect_bare_shipit_file = true

  alias respect_bare_shipit_file? respect_bare_shipit_file

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
    secrets.redis_url.present? ? URI(secrets.redis_url) : ENV["REDIS_URL"]
  end

  def redis
    @redis ||= Redis.new(
      url: redis_url.to_s.presence,
      ssl: redis_ssl_params,
      logger: Rails.logger,
      reconnect_attempts: 3,
      reconnect_delay: 0.5,
      reconnect_delay_max: 1,
    )
  end

  def redis=(client)
    @redis ||= client
  end

  def redis_ssl_params
    if(ENV['REDIS_SSL_VERIFY'] == 'false')
      {
        verify_mode: OpenSSL::SSL::VERIFY_NONE
      }
    else
      {}
    end
  end

  module SafeJSON
    class << self
      def load(serial)
        return nil if serial.nil?

        # JSON.load is unsafe, we should use parse instead
        JSON.parse(serial)
      end

      def dump(object)
        JSON.dump(object)
      end
    end
  end

  module TransitionalSerializer
    SafeYAML = Paquito::SafeYAML.new(deprecated_classes: ["ActiveSupport::HashWithIndifferentAccess"])

    class << self
      def load(serial)
        return if serial.nil?

        JSON.parse(serial)
      rescue JSON::ParserError
        SafeYAML.load(serial)
      end

      def dump(object)
        return if object.nil?

        JSON.dump(object)
      end
    end
  end

  self.database_serializer = TransitionalSerializer

  def serialized_column(attribute_name, type: nil, coder: nil)
    column = Paquito::SerializedColumn.new(database_serializer, type, attribute_name:)
    if coder
      Paquito.chain(coder, column)
    else
      column
    end
  end

  def github(organization: github_default_organization)
    # Backward compatibility
    # nil signifies the single github app config schema is being used
    if github_default_organization.nil?
      config = secrets.github
    else
      config = github_app_config(organization)
      raise GithubOrganizationUnknown, organization if config.nil?
    end
    @github ||= {}
    @github[organization] ||= GitHubApp.new(organization, config)
  end

  def github_default_organization
    return nil unless secrets&.github

    org = secrets.github.keys.first
    TOP_LEVEL_GH_KEYS.include?(org) ? nil : org
  end

  def github_organizations
    return [nil] unless github_default_organization

    secrets.github.keys
  end

  def github_app_config(organization)
    github_config = secrets.github.deep_transform_keys(&:downcase)
    github_organization = organization.downcase.to_sym
    github_config[github_organization]
  end

  def legacy_github_api
    return unless secrets&.github_api.present?

    @legacy_github_api ||= github.new_client(access_token: secrets.github_api[:access_token])
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
    if secrets.user_access_tokens_key.present?
      secrets.user_access_tokens_key
    elsif secrets.secret_key_base
      Digest::SHA256.digest("user_access_tokens_key#{secrets.secret_key_base}")
    end
  end

  def host
    secrets.host.presence
  end

  def default_merge_method
    secrets.default_merge_method || 'merge'
  end

  def update_latest_deployed_ref
    secrets.update_latest_deployed_ref
  end

  def git_progress_output
    secrets.git_progress_output || false
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
      host
    ].all?(&:present?)
  end

  def env
    { 'SHIPIT' => '1' }.merge(secrets.env || {})
  end

  def shell_paths
    [Shipit::Engine.root.join('lib', 'snippets').to_s]
  end

  def revision
    @revision ||= if revision_file.exist?
                    revision_file.read
                  else
                    `git rev-parse HEAD`
                  end.strip
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

  def use_git_askpass?
    @use_git_askpass.nil? ? true : @use_git_askpass
  end

  protected

  def revision_file
    Rails.root.join('REVISION')
  end

  def secrets
    Rails.application.credentials
  end
end

require 'shipit/engine'
