# typed: true
module Shipit
  module CastValue
    def to_boolean(value)
      ActiveModel::Type::Boolean.new.serialize(value)
    end

    module_function :to_boolean
  end
end
