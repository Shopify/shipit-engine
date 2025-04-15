# frozen_string_literal: true

class AsciiOnlyValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value && !value.ascii_only?

    record.errors.add(attribute, :ascii)
  end
end
