Airbrake.configure do |config|
  config.api_key = 'd7a2d705a0f7b9ccd6e300ab51b4cc0a'
  config.host    = 'exceptions.shopify.com'
  config.port    = 443
  config.secure  = true
  ENV.keys.each do |filtered_key|
    config.rake_environment_filters << filtered_key
  end
end

require 'resque/failure/multiple'
require 'resque/failure/airbrake'

Resque::Failure::Multiple.classes = [Resque::Failure.backend, Resque::Failure::Airbrake]
Resque::Failure.backend = Resque::Failure::Multiple