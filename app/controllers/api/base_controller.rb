module Api
  class BaseController < ActionController::Base
    include Cacheable
    include Paginable

    before_action :authenticate_api_client

    def index
      render json: {stacks_url: api_stacks_url}
    end

    private

    def authenticate_api_client
      @current_api_client = authenticate_with_http_basic do |*parts|
        token = parts.select(&:present?).join('--')
        ApiClient.authenticate(token)
      end
      return if @current_api_client
      headers['WWW-Authenticate'] = 'Basic realm="Authentication token"'
      render json: {message: 'Bad credentials'}, status: :unauthorized
    end

    attr_reader :current_api_client

    def current_user
      @current_user ||= identify_user || AnonymousUser.new
    end

    def identify_user
      user_login = request.headers['X-Shipit-User'].presence
      User.find_by(login: user_login) if user_login
    end
  end
end
