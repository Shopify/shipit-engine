module Shipit
  class HookSerializer < ActiveModel::Serializer
    include ConditionalAttributes

    has_one :stack
    attributes :id, :url, :content_type, :events, :insecure_ssl, :created_at, :updated_at

    def include_stack?
      object.scoped?
    end
  end
end
