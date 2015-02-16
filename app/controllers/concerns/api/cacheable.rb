module Api
  module Cacheable
    def render_resources(resources)
      return false unless stale?(etag: resources, last_modified: resources.map(&:updated_at).max, template: false)
      render json: resources
    end
  end
end
