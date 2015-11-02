class AsciiOnlyValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    value.encode(Encoding::ASCII)
  rescue Encoding::UndefinedConversionError
    record.errors.add(attribute, :ascii)
  end
end
