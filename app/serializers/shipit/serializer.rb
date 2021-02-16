# frozen_string_literal: true
module Shipit
  class Serializer < Panko::Serializer
    include Engine.routes.url_helpers
    class << self
      def for(object)
        if object.nil?
          self
        elsif object.is_a?(Array)
          self.for(object.first)
        else
          "#{object.class.name}Serializer".safe_constantize
        end
      end

      def build(object)
        self.for(object).new.serialize(object)
      end
    end
  end
end
