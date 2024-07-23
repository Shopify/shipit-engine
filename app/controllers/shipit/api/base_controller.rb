# frozen_string_literal: true
module Shipit
  module Api
    class BaseController < ActionController::Base
      skip_before_action :verify_authenticity_token, raise: false

      include Shipit::Engine.routes.url_helpers
      include Rendering
      include Cacheable
      include Paginable

      rescue_from ApiClient::InsufficientPermission, with: :insufficient_permission
      rescue_from EnvironmentVariables::NotPermitted, with: :validation_error
      rescue_from TaskDefinition::NotFound, with: :not_found
      rescue_from Task::ConcurrentTaskRunning, with: :conflict

      class << self
        def require_permission(operation, scope, options = {})
          before_action(options) { require_permission!(operation, scope) }
        end
      end

      before_action :authenticate_api_client

      def index
        render(json: { stacks_url: api_stacks_url })
      end

      private

      module BasicAuth
        # Workaround for https://github.com/rails/rails/pull/44610
        extend ActionController::HttpAuthentication::Basic
        extend self

        private

        def has_basic_credentials?(request)
          request.authorization.present? && (auth_scheme(request).downcase == "basic")
        end
      end

      def namespace_for_serializer
        nil
      end

      def authenticate_api_client
        @current_api_client = if Shipit.disable_api_authentication
          UnlimitedApiClient.new
        else
          BasicAuth.authenticate(request) do |*parts|
            token = parts.select(&:present?).join('--')
            ApiClient.authenticate(token)
          end
        end
        return if @current_api_client
        headers['WWW-Authenticate'] = 'Basic realm="Authentication token"'
        render(status: :unauthorized, json: { message: 'Bad credentials' })
      end

      attr_reader :current_api_client

      def current_user
        @current_user ||= identify_user || AnonymousUser.new
      end

      def identify_user
        user_login = request.headers['X-Shipit-User'].presence
        User.where('lower(login) = ?', user_login.downcase).first if user_login
      end

      def stacks
        @stacks ||= current_api_client.stack_id? ? Stack.where(id: current_api_client.stack_id) : Stack.all
      end

      def stack
        @stack ||= stacks.from_param!(params[:stack_id])
      end

      def require_permission!(operation, scope)
        current_api_client.check_permissions!(operation, scope)
      end

      def insufficient_permission(error)
        render(status: :forbidden, json: { message: error.message })
      end

      def validation_error(error)
        render(status: :unprocessable_entity, json: { message: error.message })
      end

      def not_found(_error)
        render(status: :not_found, json: { status: '404', error: 'Not Found' })
      end

      def conflict(error)
        render(status: :conflict, json: { status: '409', error: error.message })
      end
    end
  end
end
