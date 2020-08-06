require File.expand_path('../boot', __FILE__)

require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'active_job/railtie'
require 'rails/test_unit/railtie'
require 'sprockets/railtie'

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

