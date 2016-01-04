module Shipit
  class VariableDefinition
    attr_reader :name, :title, :value, :default

    def initialize(attributes)
      @name = attributes.fetch('name')
      @title = attributes['title']
      @value = attributes['value']
      @default = attributes['default']
    end

    def to_h
      {
        'name' => @name,
        'title' => @title,
        'value' => @value,
        'default' => @default,
      }
    end
  end
end
