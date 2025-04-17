# frozen_string_literal: true

module Shipit
  class Record < ActiveRecord::Base
    self.abstract_class = true

    class << self
      def serializer_class
        if defined? @serializer_class
          @serializer_class
        else
          @serializer_class = "#{name}Serializer".safe_constantize
        end
      end
    end

    delegate :serializer_class, to: :class
  end
end
