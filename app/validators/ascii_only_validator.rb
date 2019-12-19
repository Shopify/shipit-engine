class AsciiOnlyValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value && !value.ascii_only?
      record.errors.add(attribute, :ascii)
    end
  end
end
