# typed: false
module Shipit
  module ConditionalAttributes
    extend ActiveSupport::Concern

    module ClassMethods
      def inclusion_method_for(attribute)
        @inclusion_cache ||= {}
        @inclusion_cache.fetch(attribute) do
          method = "include_#{attribute}?"
          method_defined?(method) && method
        end
      end
    end

    def filter(*)
      super.reject do |attribute|
        method = self.class.inclusion_method_for(attribute)
        method && !send(method)
      end
    end
  end
end
