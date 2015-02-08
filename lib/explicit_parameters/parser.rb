module ExplicitParameters
  class Parser < HashParser
    def from_param(values)
      result = super
      raise InvalidParameters.new(result.to_json) if result.is_a?(Errors)
      result
    end
  end
end
