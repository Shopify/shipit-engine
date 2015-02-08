module Api
  class BaseController < ActionController::Base
    before_action :authenticate_api_client

    def index
      render json: {stacks_url: api_stacks_url}
    end

    private

    def authenticate_api_client
      @current_api_client = authenticate_with_http_basic do |token|
        ApiClient.authenticate(token)
      end
      return if @current_api_client
      headers['WWW-Authenticate'] = 'Basic realm="Authentication token"'
      render json: {message: 'Bad credentials'}, status: :unauthorized
    end
  end
end
