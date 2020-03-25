# typed: false
module Shipit
  module Pagination
    extend ActiveSupport::Concern

    included do
      class_attribute :max_page_size
      class_attribute :default_page_size
      class_attribute :default_order

      self.max_page_size = 100
      self.default_page_size = 30
      self.default_order = {id: :desc}.freeze
    end

    private

    def paginate(relation)
      Shipit::Paginator.new(
        relation,
        self,
        order: default_order,
        max_page_size: max_page_size,
        default_page_size: default_page_size,
      )
    end
  end
end
