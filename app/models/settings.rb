class Settings < Settingslogic
  source "#{Rails.root}/config/settings.yml#{'.example' if Rails.env.test?}"
  namespace Rails.env
end
