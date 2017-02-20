require 'uri'

module Shipit
  class CcmenuUrlController < ShipitController
    def fetch
      uri = URI(api_stack_ccmenu_url(stack_id: stack.to_param))
      uri.query = {'token' => client.authentication_token}.to_query
      render json: {ccmenu_url: uri.to_s}
    end

    private

    def client
      @client ||= ApiClient.create_with(permissions: %w(read:stack))
                           .find_or_create_by!(creator: current_user, name: 'CCMenu Client')
    end

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
