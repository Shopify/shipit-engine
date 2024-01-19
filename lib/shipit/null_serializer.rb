# frozen_string_literal: true

module Shipit
  module NullSerializer
    extend self

    def load(object)
      object
    end

    def dump(object)
      object
    end
  end
end
