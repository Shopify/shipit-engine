$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'shipit/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name = 'shipit-engine'
  s.version = Shipit::VERSION
  s.authors = ['Jean Boussier']
  s.email = ['jean.boussier@shopify.com', 'guillaume@shopify.com']
  s.homepage = "https://github.com/shopify/shipit-engine"
  s.summary = "Application deployment software"
  s.license = "MIT"

  s.files = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"] - Dir["test/dummy/tmp/**/*"] - Dir["test/dummy/log/**/*"]

  s.add_dependency 'active_model_serializers', '~> 0.9.3'
  s.add_dependency 'ansi_stream', '~> 0.0.6'
  s.add_dependency 'attr_encrypted', '~> 3.1.0'
  s.add_dependency 'autoprefixer-rails', '~> 6.4.1'
  s.add_dependency 'coffee-rails', '~> 5.0'
  s.add_dependency 'explicit-parameters', '~> 0.4.0'
  s.add_dependency 'faraday', '~> 0.15'
  s.add_dependency 'faraday-http-cache', '~> 1.2.2'
  s.add_dependency 'gemoji', '~> 2.1'
  s.add_dependency 'jquery-rails', '~> 4.1.0'
  s.add_dependency 'lodash-rails', '~> 4.6.1'
  s.add_dependency 'octokit', '~> 4.15'
  s.add_dependency 'omniauth-github', '~> 1.4'
  s.add_dependency 'pubsubstub', '~> 0.2.0'
  s.add_dependency 'rails', '~> 6.0.0'
  s.add_dependency 'rails-timeago', '~> 2.13.0'
  s.add_dependency 'rails_autolink', '~> 1.1.6'
  s.add_dependency 'rake', '~> 12.0'
  s.add_dependency 'redis-namespace', '~> 1.6.0'
  s.add_dependency 'redis-objects', '~> 1.4.3'
  s.add_dependency 'responders', '~> 3.0'
  s.add_dependency 'safe_yaml', '~> 1.0.4'
  s.add_dependency 'sass-rails', '~> 5.0'
  s.add_dependency 'securecompare', '~> 1.0.0'
  s.add_dependency 'sprockets-rails', '>= 2.3.2'
  s.add_dependency 'state_machines-activerecord', '~> 0.6.0'
  s.add_dependency 'validate_url', '~> 1.0.0'
end
