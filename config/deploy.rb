# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'shipit2'
set :repo_url, 'git@shipit2.github.shopify.com:Shopify/shipit2.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/u/apps/shipit2'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{config/unicorn.conf.rb config/database.yml config/secrets.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{bin data log tmp vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 50

after 'deploy:publishing', 'deploy:restart', 'jobs:restart'

namespace :deploy do
  desc "Signal Unicorn to restart the application"
  task :restart do
    on roles(:app), in: :parallel do
      execute "test ! -f #{shared_path}/tmp/pids/unicorn.pid || sudo -u shipit2 /usr/local/bin/unicorn-corporify shipit2"
    end
  end
end

namespace :jobs do
  task :restart do
    on roles(:app), in: :parallel do
      execute "sv-sudo quit /etc/sv/shipit2-*-resque-*"
    end
  end
end
