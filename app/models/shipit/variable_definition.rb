# frozen_string_literal: true
module Shipit
  class VariableDefinition
    attr_reader :name, :title, :default, :select

    def initialize(attributes)
      @name = attributes.fetch('name')
      @title = attributes['title']
      @default = attributes['default'].to_s
      @default_provided = attributes.key?('default')
      @select = attributes['select'].presence
    end

    def default_provided?
      @default_provided
    end

    def override_value(value)
      @override = value.to_s
    end

    def value
      @override.presence || default
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
