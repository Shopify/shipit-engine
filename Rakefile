# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
end

require File.expand_path('../config/application', __FILE__)

Shipit::Application.load_tasks

task default: %i(test rubocop)
