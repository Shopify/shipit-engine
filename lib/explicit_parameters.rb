module ExplicitParameters
  BaseError = Class.new(StandardError)
  InvalidParameters = Class.new(BaseError)
  MissingParametersDeclaration = Class.new(BaseError)

  def self.included(base)
    base.include(ExplicitParameters::Controller) if base < ActionController::Base
  end
end
