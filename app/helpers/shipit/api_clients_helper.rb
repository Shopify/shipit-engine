# frozen_string_literal: true
module Shipit
  module ApiClientsHelper
    def api_client_token(api_client)
      if api_client.created_at >= 5.minutes.ago && current_user == api_client.creator
        api_client.authentication_token
      else
        "#{api_client.authentication_token[0..5]}************************"
      end
    end
  end
end
