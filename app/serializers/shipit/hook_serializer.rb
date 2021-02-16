# frozen_string_literal: true
module Shipit
  class HookSerializer < Serializer
    attributes :id, :stack, :url, :delivery_url, :content_type, :events, :insecure_ssl, :created_at, :updated_at

    def stack
      object.stack || SKIP
    end

    def url
      if object.scoped?
        api_stack_hook_url(object.stack, object)
      else
        api_hook_url(object)
      end
    end
  end
end
