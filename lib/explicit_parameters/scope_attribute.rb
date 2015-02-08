class ScopeAttribute < Virtus::Attribute
  class << self
    attr_accessor :scope

    def for(scope)
      klass = Class.new(self)
      klass.scope = scope
      klass
    end

    def model
      scope.is_a?(ActiveRecord::Relation) ? scope.model : scope
    end
  end

  def coerce(value)
    return unless value.present?
    if self.class.scope.respond_to?(:from_param)
      self.class.scope.from_param(value)
    else
      self.class.scope.find_by_id(value)
    end
  end

  def value_coerced?(value)
    value.is_a?(self.class.model)
  end
end
