# typed: false
module Shipit
  module Api
    module Paginable
      extend ActiveSupport::Concern

      LINK = 'Link'.freeze

      included do
        class_attribute :max_page_size
        class_attribute :default_page_size
        class_attribute :default_order

        self.max_page_size = 100
        self.default_page_size = 30
        self.default_order = {id: :desc}.freeze
      end

      private

      def render_resources(resource, *)
        paginator = Shipit::Paginator.new(
          resource,
          self,
          order: default_order,
          max_page_size: max_page_size,
          default_page_size: default_page_size,
        )
        headers[LINK] = render_links(paginator.links)
        super(paginator.to_a)
      end

      def render_links(links)
        links.map { |rel, url| %(<#{url}>; rel="#{rel}") }.join(', ')
      end
    end
  end
end
