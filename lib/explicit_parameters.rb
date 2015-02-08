module ExplicitParameters
  BaseError = Class.new(StandardError)
  MissingParameter = Class.new(BaseError)
  InvalidParameters = Class.new(BaseError)
  MissingParametersDeclaration = Class.new(BaseError)

  def self.included(base)
    base.include(ExplicitParameters::Controller) if base < ActionController::Base
  end
end
