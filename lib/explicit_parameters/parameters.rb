module ExplicitParameters
  class Parameters
    include Virtus.model
    include ActiveModel::Validations

    class CoercionValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.validate_attribute_coercion!(attribute, value)
      end
    end

    class RequiredValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.validate_attribute_provided!(attribute, value)
      end
    end

    class << self
      def parse!(params)
        new(params).validate!
      end

      def define(&block)
        Class.new(self, &block)
      end

      def requires(name, type, options = {})
        accepts(name, type, options.merge(required: true))
      end

      def accepts(name, type, options = {})
        attribute(name, type, options.slice(:default))
        validations = options.except(:default)
        validations[:coercion] = true
        validates(name, validations)
      end

      def optional_attributes
        @optional_attributes ||= []
      end
    end

    def initialize(attributes = nil)
      record_missing_attributes(attributes) if attributes
      super
    end

    def validate!
      raise InvalidParameters.new(errors.to_json) unless valid?
      self
    end

    def validate_attribute_provided!(attribute_name, value)
      errors.add attribute_name, "is required" if @missing_attributes.include?(attribute_name)
    end

    def validate_attribute_coercion!(attribute_name, value)
      attribute = attribute_set[attribute_name]
      return if value.nil?
      return if attribute.value_coerced?(value)
      errors.add attribute_name, "#{value.inspect} is not a valid #{attribute.type.name.demodulize}"
    end

    def to_hash
      super.except(*@missing_attributes)
    end

    private

    def record_missing_attributes(attributes)
      @missing_attributes = (attribute_set.map(&:name).map(&:to_s) - attributes.keys.map(&:to_s)).map(&:to_sym)
    end
  end
end
