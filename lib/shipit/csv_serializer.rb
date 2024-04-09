# frozen_string_literal: true

module Shipit
  module CSVSerializer
    extend self

    def load(payload)
      return [] if payload.blank?
      payload.split(',')
    end

    def dump(array)
      return nil if array.blank?
      Array.wrap(array).join(',')
    end
  end
end
