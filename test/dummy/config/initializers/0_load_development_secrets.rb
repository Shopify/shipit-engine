local_secrets = Shipit::Engine.root.join('config/secrets.development.yml')
if local_secrets.exist?
  secrets = YAML.load(local_secrets.read).deep_symbolize_keys
  if Rails.env.development?
    Rails.application.credentials.deep_merge!(secrets)
  elsif Rails.env.test?
    Rails.application.credentials.merge!(redis_url: secrets[:redis_url])
  end
end
