module Shipit
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
      links = {first: link_to(since: nil, page_size: (page_size if page_size != @default_page_size))}
      links[:next] = link_to(since: to_a.last.id) unless last_page?
      links
    end

    private

    attr_reader :controller, :order, :page_size, :since

    def last_page?
      @resources.size <= page_size
    end

    def link_to(params)
      controller.url_for(controller.request.parameters.merge(params))
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
