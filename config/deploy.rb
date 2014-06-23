# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'transmuter'
set :repo_url, 'git@github.com:Shopify/alchemy-transmuter.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }
if ENV.has_key? "REVISION" or ENV.has_key? "BRANCH_NAME"
  set :branch, ENV["REVISION"] || ENV["BRANCH_NAME"]
end

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/u/apps/transmuter'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
if Dir.exists? File.join(File.dirname(File.dirname(File.expand_path(__FILE__))),'spells/coreos')
  set :linked_files, %w{config/coreos_bootstrap.id config/slave_private_key.pem config/slave_public_key.pem config/deploy_users.yml config/chaos_users.yml}
end

if any?(:linked_files)
  set :linked_files, fetch(:linked_files).push('config/collins.yml')
else
  set :linked_files, %w{config/collins.yml}
end
# Default value for linked_dirs is []
#set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system config db}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system db}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do

  desc 'Restart application'
  task :restart do  
    on roles(:app), in: :sequence, wait: 5 do  
        execute :sv, 'restart transmuter'
    end 
  end 

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
    end
  end
end
