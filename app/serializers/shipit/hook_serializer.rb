# frozen_string_literal: true

module Shipit
  class HookSerializer < ActiveModel::Serializer
    include ConditionalAttributes

    has_one :stack
    attributes :id, :url, :delivery_url, :content_type, :events, :insecure_ssl, :created_at, :updated_at

    def url
      if object.scoped?
        api_stack_hook_url(object.stack, object)
      else
        api_hook_url(object)
      end
    end

    def include_stack?
      object.scoped?
    end
  end
end
