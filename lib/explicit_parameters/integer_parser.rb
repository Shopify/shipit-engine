module ExplicitParameters
  class IntegerParser < ScalarParser
    def from_param(value)
      Integer(value)
    rescue TypeError
      raise ArgumentError
    end
  end
end
