#!/usr/bin/env ruby 

# Hot update module load path
['.','models','lib','spells'].each do | path |
  $LOAD_PATH.unshift File.join(File.dirname(File.expand_path(__FILE__)),path)
end

# Upstream
require 'eventmachine'
require 'sinatra'
require 'sinatra/config_file'
require 'thin'
require 'data_mapper'

# Custom
require 'spellcaster'
require 'http'

# We've embedded sinatra inside of eventmachine so we can do background work if we need
# http://recipes.sinatrarb.com/p/embed/event-machine
class Transmuter

  def initialize(settings)
    @settings = settings

    if ENV['UPDATER_ENVIRONMENT'] == "production"
      puts 'production'
      db_url = "mysql://#{settings.db['user']}:#{settings.db['password']}@#{settings.db['hostname']}/#{settings.db['dbname']}"
    else
      db_path = "#{File.join(File.dirname(File.expand_path(__FILE__)),'db','development.db')}"
      puts "Using DB at #{db_path}"
      db_url = "sqlite3://#{db_path}"
    end

    DataMapper.setup :default, db_url 
    DataMapper.finalize
    DataMapper.auto_upgrade!

    @jobs = {}
  end

  def run()

    # Start the reactor
    EM.run do

      server     = @settings.main['server']    # 'thin'
      host       = @settings.main['host']      # '0.0.0.0'
      port       = @settings.main['port']      # '9000'

      settings = @settings

      dispatch = Rack::Builder.app do
        map '/' do
          run TransmuterHTTP.new(settings)
        end
      end

      # NOTE that we have to use an EM-compatible web-server. There
      # might be more, but these are some that are currently available.
      unless ['thin', 'hatetepe', 'goliath'].include? server
        raise "Need an EM webserver, but #{server} isn't"
      end

      # Start the web server. Note that you are free to run other tasks
      # within your EM instance.
      Rack::Server.start({
        app:    dispatch,
        server: server,
        Host:   host,
        Port:   port
      })
      init_sighandlers

    end
  end

  # Needed during testing
  def init_sighandlers
    trap(:INT)  {"Got interrupt"; EM.stop(); exit }
    trap(:TERM) {"Got term";      EM.stop(); exit }
    trap(:KILL) {"Got kill";      EM.stop(); exit }
  end

end

# Load configs
# To do: clean up log loading
config = "#{File.join(File.dirname(File.expand_path(__FILE__)),'config','config.yml')}"
database_config = "#{File.join(File.dirname(File.expand_path(__FILE__)),'config','database.yml')}"
options_config = "#{File.join(File.dirname(File.expand_path(__FILE__)),'config','options.yml')}"
secrets_config = "#{File.join(File.dirname(File.expand_path(__FILE__)),'config','secrets.yml')}"
config_file config
config_file database_config
config_file options_config
config_file secrets_config

# Write any log information immediately
$stdout.sync = true
$stderr.sync = true

# start the applicatin
transmuter = Transmuter.new(settings)
transmuter.run
