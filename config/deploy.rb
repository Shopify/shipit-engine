# config valid only for Capistrano 3.1
lock '3.1.0'

set :bundle_bins, fetch(:bundle_bins, []).push('whenever')

set :application, 'shipit'
set :repo_url, 'git@shipit2.github.shopify.com:Shopify/shipit2.git'
set :branch, ENV['REVISION'] || ENV['BRANCH_NAME'] || 'master'

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/u/apps/shipit'
set :format, :pretty

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w(config/database.yml config/secrets.yml config/settings.yml)

# Default value for linked_dirs is []
set :linked_dirs, %w(bin data log tmp vendor/bundle public/system public/assets)

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 50

before 'deploy:assets:precompile', 'deploy:use_deploy_log'
before 'deploy:symlink:release', 'deploy:use_runtime_log'

after 'deploy:publishing', 'deploy:restart'

namespace :deploy do
  task :use_deploy_log do
    on roles(:app), in: :parallel do
      within release_path do
        execute(*%W(ln -nsfT #{shared_path}/deploy_log ./log))
      end
    end
  end

  task :use_runtime_log do
    on roles(:app), in: :parallel do
      within release_path do
        execute(*%W(ln -nsfT #{shared_path}/log ./log))
      end
    end
  end

  desc "Signal Thin services to restart the application"
  task :restart do
    on roles(:app), in: :parallel do
      execute "sv-sudo hup /etc/sv/shipit-thin-*"
    end
  end

  desc "Regenerate cron tasks"
  task :cron do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute 'whenever', '--write-crontab'
        end
      end
    end
  end

end

namespace :jobs do
  desc "restart the job workers"
  task :restart do
    on roles(:app), in: :parallel do
      execute "sv-sudo quit /etc/sv/shipit-*-resque-*"
    end
  end
end

before 'deploy:finishing', 'deploy:cron'
after 'deploy:finishing_rollback', 'deploy:cron' # If anything goes wrong, undo.
after 'deploy:publishing', 'jobs:restart' # I don't know why this needs to be after jobs:restart :(
