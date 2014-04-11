Airbrake.configure do |config|
  config.api_key = '0a5e1cc4cb2c306b8cb3281b2a79d555'
  config.host    = 'exceptions.shopify.com'
  config.port    = 443
  config.secure  = true
  ENV.keys.each do |filtered_key|
    config.rake_environment_filters << filtered_key
  end
end
