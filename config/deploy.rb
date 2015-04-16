lock '3.4.0'

module UserSwitching
  def execute(command, *args)
    if command == :rake
      as('shipit') { super }
    else
      super
    end
  end
end
SSHKit.config.backend.prepend(UserSwitching)

set :bundle_bins, fetch(:bundle_bins, []).push('whenever')

set :application, 'shipit'
set :repo_url, 'git@shipit2.github.shopify.com:Shopify/shipit2.git'
set :branch, ENV['REVISION'] || ENV['BRANCH_NAME'] || 'master'

set :deploy_to, '/u/apps/shipit'
set :format, :pretty

set :linked_files, %w(config/database.yml config/secrets.yml)
set :linked_dirs, %w(bin data log tmp vendor/bundle public/system public/assets)

set :keep_releases, 10

set :bugsnag_api_key, '8f5ef714c28f7ea7b5c1fde664d3dc7a'

before 'deploy:assets:precompile', 'deploy:use_deploy_log'
before 'deploy:symlink:release', 'deploy:use_runtime_log'

after 'deploy:publishing', 'deploy:restart'

namespace :deploy do
  task :use_deploy_log do
    on roles(:app) do
      within release_path do
        execute :ln, '-nsfT', shared_path.join('deploy_log'), './log'
      end
    end
  end

  task :use_runtime_log do
    on roles(:app) do
      within release_path do
        execute :ln, '-nsfT', shared_path.join('log'), './log'
      end
    end
  end

  desc "Signal Thin services to restart the application"
  task :restart do
    on roles(:app) do
      execute 'sv-sudo', 'hup', '/etc/sv/shipit-thin-*'
    end
  end

  desc "Regenerate cron tasks"
  task :cron do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          as 'shipit' do
            execute 'whenever', '--write-crontab'
          end
        end
      end
    end
  end

  desc "Store the deployed revision in a REVISION file"
  task :write_revision do
    on roles(:app) do
      within release_path do
        execute 'echo', fetch(:current_revision), '> REVISION'
      end
    end
  end
end

namespace :jobs do
  desc "restart the job workers"
  task :restart do
    on roles(:app) do
      execute 'sv-sudo', 'quit', '/etc/sv/shipit-*-resque-*'
    end
  end
end

before 'deploy:finishing', 'deploy:cron'
after 'deploy:finishing_rollback', 'deploy:cron' # If anything goes wrong, undo.
after 'deploy:publishing', 'jobs:restart' # I don't know why this needs to be after jobs:restart :(
after 'deploy:log_revision', 'deploy:write_revision'
