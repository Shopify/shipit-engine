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
          head :no_content, options.reverse_merge(content_type: 'application/json')
        elsif resource.errors.any?
          render options.reverse_merge(status: :unprocessable_entity, json: {errors: resource.errors})
        else
          render options.reverse_merge(json: resource)
        end
      end
    end
  end
end
