class Settings < Settingslogic
  source Rails.env.test? ? "#{Rails.root}/config/settings.example.yml" : "#{Rails.root}/config/settings.yml"
  namespace Rails.env
end
