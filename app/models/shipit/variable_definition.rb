module Shipit
  class VariableDefinition
    attr_reader :name, :title, :default, :select

    def initialize(attributes)
      @name = attributes.fetch('name')
      @title = attributes['title']
      @default = attributes['default'].to_s
      @select = attributes['select'].presence
    end

    def to_h
      {
        'name' => @name,
        'title' => @title,
        'default' => @default,
        'select' => @select,
      }
    end
  end
end
