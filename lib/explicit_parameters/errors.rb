module ExplicitParameters
  class Errors
    extend Forwardable

    def_delegators :@errors, :as_json, :empty?

    def initialize
      @errors = {}
    end

    def report_missing(name)
      @errors[name] = "#{name} is required"
    end

    def report_invalid(name, value, parser)
      @errors[name] = "#{value.inspect} is not a valid #{parser.name}"
    end

    def add(name, errors)
      @errors[name] = errors
    end
  end
end
