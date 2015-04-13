if Shipit.bugsnag_api_key && !Rails.application.config.consider_all_requests_local
  Bugsnag.configure do |config|
    config.api_key = Shipit.bugsnag_api_key
  end
end
