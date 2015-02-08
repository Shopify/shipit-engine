module ExplicitParameters
  class HashParser
    def initialize(&block)
      @parameters = {}
      instance_exec(&block)
    end

    def requires(name, type, *args)
      @parameters[name] = parser_for(type).new(name, true, *args)
    end

    def accepts(name, type, *args)
      @parameters[name] = parser_for(type).new(name, false, *args)
    end

    def from_param(values)
      errors = Errors.new
      parsed_values = {}
      @parameters.each do |name, parser|
        if values.has_key?(name)
          value = values[name]
          begin
            case result = parser.from_param(value)
            when Errors
              errors.add(name, result)
            else
              parsed_values[name] = result
            end
          rescue ArgumentError
            errors.report_invalid(name, value, parser)
          end
        elsif parser.default?
          parsed_values[name] = parser.default
        elsif parser.required?
          errors.report_missing(name)
        end
      end

      errors.empty? ? parsed_values : errors
    end

    private

    def parser_for(type)
      ExplicitParameters.const_get("#{type}Parser")
    end
  end
end
