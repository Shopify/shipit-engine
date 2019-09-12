require File.expand_path('../boot', __FILE__)

require 'rails/all'

Bundler.require(*Rails.groups)
require "shipit"

begin
  require "pry"
rescue LoadError
end

module Shipit
  class Application < Rails::Application
    config.load_defaults 6.0
  end
end

