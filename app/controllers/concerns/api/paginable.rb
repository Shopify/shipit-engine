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

    def render_resources(resource)
      paginator = Paginator.new(
        resource,
        self,
        order: default_order,
        max_page_size: max_page_size,
        default_page_size: default_page_size,
      )
      headers[LINK] = paginator.links
      super(paginator.to_a)
    end

    class Paginator
      def initialize(resources, controller, order: {id: :desc}, max_page_size: 100, default_page_size: 30)
        @order = order
        @controller = controller
        @since = controller.params[:since].presence
        page_size = controller.params[:page_size].presence || default_page_size
        @page_size = [page_size.to_i, max_page_size].min
        @default_page_size = default_page_size
        @resources = fetch(resources)
      end

      def to_a
        @resources[0, @page_size]
      end

      def links
        links = [link_to(:first, since: nil, page_size: (page_size if page_size != @default_page_size))]
        links << link_to(:next, since: to_a.last.id) unless @resources.size < (page_size + 1)
        links.join(', ')
      end

      private

      attr_reader :controller, :order, :page_size, :since

      def link_to(rel, params)
        url = controller.url_for(controller.request.parameters.merge(params))
        %(<#{url}>; rel="#{rel}")
      end

      def fetch(resources)
        scope = resources.order(order).limit(page_size + 1)

        if since
          column = scope.model.arel_table[order_column]
          operator = ascending? ? :gt : :lt
          scope = scope.where(column.public_send(operator, since))
        end

        scope.to_a
      end

      def order_column
        order.keys.first
      end

      def ascending?
        order.values.first.to_sym == :asc
      end
    end
  end
end
