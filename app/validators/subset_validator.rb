# frozen_string_literal: true
class SubsetValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    superset = options[:of]
    rest = value - superset
    record.errors.add(attribute, :subset, options) unless rest.empty?
  end
end
