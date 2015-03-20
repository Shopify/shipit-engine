module Api
  module Cacheable
    def render_resources(resources)
      super if stale?(etag: resources, last_modified: resources.map(&:updated_at).max, template: false)
    end

    def render_resource(resource)
      super if stale?(etag: resource, last_modified: resource.updated_at, template: false)
    end
  end
end
