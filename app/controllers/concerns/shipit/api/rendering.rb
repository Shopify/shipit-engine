module Shipit
  module Api
    module Rendering
      private

      def render_resources(resources, options = {})
        options[:json] = resources
        render options
      end

      def render_resource(resource, options = {})
        if resource.destroyed?
          options[:status] = :no_content
          options[:text] = nil
        elsif resource.errors.any?
          options[:json] = {errors: resource.errors}
          options[:status] = :unprocessable_entity
        else
          options[:json] = resource
        end
        render options
      end
    end
  end
end
