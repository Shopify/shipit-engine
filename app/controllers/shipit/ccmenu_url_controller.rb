require 'uri'

module Shipit
  class CcmenuUrlController < ShipitController
    def fetch
      uri = URI(api_stack_ccmenu_url(stack_id: stack.to_param))
      uri.user = client.authentication_token
      render json: {ccmenu_url: uri.to_s}
    end

    private

    def client
      @client ||= Shipit::ApiClient.create_with(permissions: %w(read:stack))
                                   .find_or_create_by!(creator: current_user, name: 'CCMenu Client')
    end

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
