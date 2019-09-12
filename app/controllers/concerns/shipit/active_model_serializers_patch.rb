module Shipit
  module ActiveModelSerializersPatch
    private

    def namespace_for_serializer
      # TODO: This is a monkey patch for active_model_serializers 0.9.7.
      # It's really outdated and newer versions aren't really a suitable replacement.
      # We should look into simply getting rid of it.
      @namespace_for_serializer ||= self.class.module_parent unless self.class.module_parent == Object
    end
  end
end
