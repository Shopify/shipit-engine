# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require 'rubocop/rake_task'

RuboCop::RakeTask.new

require File.expand_path('../config/application', __FILE__)

Shipit::Application.load_tasks

task default: %i(rubocop test)
