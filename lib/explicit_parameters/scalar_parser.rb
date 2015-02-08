module ExplicitParameters
  class ScalarParser
    attr_reader :name, :required
    alias_method :required?, :required

    def initialize(name, required, options = nil)
      @name = name
      @required = required
      @default = options[:default] if options && options.has_key?(:default)
    end

    def name
      self.class.name.demodulize.gsub(/Parser$/, '')
    end

    def from_param(value)
      raise NotImplementedError
    end

    def default
      raise RuntimeError.new("No default provided for #{name}") unless default?
      @default.duplicable? ? @default.dup : @default
    end

    def default?
      defined? @default
    end
  end
end
