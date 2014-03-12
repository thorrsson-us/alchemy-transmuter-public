require 'spell'

require 'resolv'

$base = File.dirname(File.dirname(File.dirname(File.expand_path(__FILE__))))

# Spell to bootstrap CoreOS servers
# @note this will only load them into ram, not install to disk
# @note this contains some Shopify specific setup!
class CoreosSpell < Spell


  # Render a URL that doesn't depend on state
  # @note called via /spell/render/coreos/cloudconfig
  # @note HTTP 400: missing required parameter
  # @note HTTP 401: Access denied - specified host is not whitelited
  # @param [TransmuterHTTP] transmuter The Sinatra frontend to handle client interaction
  # @param [Hash] env Environment variables at the time of the request
  # @param settings Sinatra configuration settings for this spell
  # @param request Sinatra request object that this is rendering for
  # @todo fixme - I'm a broken endpoint - a don't correctly render the file
  def self.render_cloudconfig(transmuter,env,settings,request)

    puts "Grabbing cloudconfig"
    dns = Resolv::DNS.new(:nameserver => settings['coreos']['dns'])
    remote = env['HTTP_X_FORWARDED_FOR']
    names = dns.getnames(remote)

    allowed = settings['coreos']['nodes']
    puts remote
    puts allowed
    match = names.detect {|name| allowed.include?(name.to_s) }
    message = "Access denied, ip:#{remote} rdns:'#{match}' not on the whitelist."
    puts message unless match
    transmuter.halt(401, message) unless match

    deploy_users_file = File.join($base,'config','deploy_users.yml')
    chaos_users_file = File.join($base,'config','chaos_users.yml')

    opts = settings.clone

    opts['deploy_users'] = YAML::load(File.open(deploy_users_file))
    puts "Warning: deploy user file #{deploy_users_file} looks suspect" unless opts['deploy_users']
    opts['chaos_users'] = YAML::load(File.open(chaos_users_file))
    puts "Warning: chaos user file #{chaos_users_file} looks suspect" unless opts['chaos_users']
    opts ['btrfs_drive'] = settings['coreos']['btrfs']

    return transmuter.erb(:cloudconfig, :locals => { :opts => opts })
  end


  # Render a URL that doesn't depend on state
  # @note called via /spell/render/coreos/borgboot
  # @note HTTP 400: missing required parameter
  # @note HTTP 401: Inconsistent address - false truth detected
  # @note HTTP 404: invalid SKU
  # @note HTTP 409: Misconfigured server, there is no payload directory specified
  # @param [TransmuterHTTP] transmuter The Sinatra frontend to handle client interaction
  # @param [Hash] env Environment variables at the time of the request
  # @param settings Sinatra configuration settings for this spell
  # @param request Sinatra request object that this is rendering for
  # @todo fixme - i'm a broken endpoint, I depend on relative paths that may not be correct
  def self.render_borgboot(transmuter,env,settings,request)

    sku = request.params["sku"]
    puts "Trying to render borgboot for #{sku}"
    transmuter.halt(400,"missing sku") unless sku

    collins = Collins.new

    asset = collins.getFullAssetData(sku)
    transmuter.halt(404,"unrecognized sku") unless asset

    address = asset["ADDRESSES"].first["ADDRESS"]
    remote = env['HTTP_X_FORWARDED_FOR']

    if address != remote
      message = "Bad request IP, got #{remote} but expected #{address} -- ensure Collins is up to date."
      collins.updateLog(sku, message, 'ERROR')
      halt(401, message)
    end

    transmuter.halt(409, "No payload directory!") unless settings.has_key? 'coreos' and settings['coreos'].has_key? 'payload_directory'
    payload_dir = settings['coreos']['payload_directory']

    ssh_options = "-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -i #{File.join($base,"config/coreos_bootstrap.id")} core@#{address}"
    steps = [
      "ssh #{ssh_options} \"sudo mkdir -p #{payload_dir}\"",
      "dd if=#{File.join($base,"config/slave_public_key.pem")} | ssh #{ssh_options} \"sudo dd of=#{File.join(payload_dir,"publickey.pem")}\" ",
      "dd if=#{File.join($base,"config/slave_private_key.pem")} | ssh #{ssh_options} \"sudo dd of=#{File.join(payload_dir,"privatekey.pem")}\" "
    ]

    steps.each do |cmd|
      puts "Running: #{cmd}"
      output = `#{cmd}`
      puts output

      if $? != 0
        message = "Provision failed, command:#{cmd} rc:#{$?} output:#{output}"
        collins.updateLog(sku, message, 'ERROR')
        transmuter.halt(500, message)
      end
    end

    collins.updateLog(sku, "Completed CoreOS bootstrap of #{sku} at #{address}.")
    return transmuter.body("Bootstrap completed")
  end


  # Render a URL that doesn't depend on state
  # @note called via /spell/render/coreos/boot
  # @note HTTP 400: missing required parameter
  # @note HTTP 409: build requested to boot does not exist
  # @param [TransmuterHTTP] transmuter The Sinatra frontend to handle client interaction
  # @param [Hash] env Environment variables at the time of the request
  # @param settings Sinatra configuration settings for this spell
  # @param request Sinatra request object that this is rendering for
  def self.render_boot(transmuter,env,settings,request)

    transmuter.halt(400, "No build specified") unless request.params.has_key? 'build'
    build = request.params['build']
    transmuter.halt(409, "Requested build does not exist") unless settings.has_key? 'coreos' and settings['coreos'].has_key? 'builds' and settings['coreos']['builds'].has_key? build

    return transmuter.erb(:coreos_boot, :locals => { :opts => settings['coreos']['builds'][build] })
  end


  # The run method initializes the state, and handles state transitioning
  def cast
  end

  # Allows for servers being transmuted to communicate with the spell about their progress
  # @param [String] message The message to send to the spell
  def notify(message)
    puts "Got message #{message}"
  end

  # Respond when receiving a message, can vary based on state
  # @param [Hash] options The options passed via http
  def respond(options = {})
    puts "Responding in state #{@state}"
  end
end
