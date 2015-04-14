# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shipit/version'

Gem::Specification.new do |spec|
  spec.name          = "shipit"
  spec.version       = Shipit::VERSION
  spec.authors       = ["Guillaume Malette"]
  spec.email         = ["gmalette@gmail.com"]
  spec.summary       = %q{done}
  spec.description   = %q{done}
  spec.homepage      = "http://wako.ca"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'rails', '~> 4.2.1'
  spec.add_dependency 'responders'
  spec.add_dependency 'sprockets', '~> 2.12'
  spec.add_dependency 'mysql2'
  spec.add_dependency 'sass-rails'
  spec.add_dependency 'uglifier'
  spec.add_dependency 'coffee-rails'
  spec.add_dependency 'jquery-rails'
  spec.add_dependency 'state_machine'
  spec.add_dependency 'resque', '1.26.pre.0'
  spec.add_dependency 'resque-workers-lock'#, require: 'resque/plugins/workers/lock'
  spec.add_dependency 'redis-rails'
  spec.add_dependency 'thin'
  spec.add_dependency 'octokit'
  spec.add_dependency 'faker'
  spec.add_dependency 'omniauth'
  spec.add_dependency 'omniauth-github'
  spec.add_dependency 'omniauth-google-oauth2'
  spec.add_dependency 'safe_yaml'#, require: 'safe_yaml/load'
  spec.add_dependency 'pubsubstub', '~> 0.0.7'
  spec.add_dependency 'securecompare', '~>1.0'
  spec.add_dependency 'rails-timeago', '~> 2.0'
  spec.add_dependency 'ansi_stream', '~> 0.0.4'
  spec.add_dependency 'heroku'
  spec.add_dependency 'faraday'
  spec.add_dependency 'faraday-http-cache'
  spec.add_dependency 'validate_url'
  spec.add_dependency 'active_model_serializers'
  spec.add_dependency 'explicit-parameters'
  spec.add_dependency 'rack-cors'#, require: 'rack/cors'
  spec.add_dependency 'pry'
end
