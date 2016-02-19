module Shipit
  class VariableDefinition
    attr_reader :name, :title, :default

    def initialize(attributes)
      @name = attributes.fetch('name')
      @title = attributes['title']
      @default = attributes['default'].to_s
    end

    def to_h
      {
        'name' => @name,
        'title' => @title,
        'default' => @default,
      }
    end
  end
end
