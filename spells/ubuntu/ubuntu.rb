require 'spell'

# Bootstrap an Ubunut server by dynamically rendering a preseed
# @todo specify which options can be overriden directly from collins attributes.
class UbuntuSpell < Spell

  # Render a URL that doesn't depend on state
  # @note called via /spell/render/ubuntu/preseed
  # @note HTTP 400: missing required parameter
  # @param [TransmuterHTTP] transmuter The Sinatra frontend to handle client interaction
  # @param [Hash] env Environment variables at the time of the request
  # @param settings Sinatra configuration settings for this spell
  # @param request Sinatra request object that this is rendering for
  def self.render_preseed(transmuter,env,settings,request)
    
    params = request.params
    transmuter.halt(400,"missing sku") unless params.has_key? 'sku'
    transmuter.halt(400,"missing dhcp-server") unless params.has_key? 'dhcp-server'
    transmuter.halt(400,"missing codename") unless params.has_key? 'codename'
    transmuter.halt(400,"missing swapsize") unless params.has_key? 'swapsize'

    opts = settings['menu']
    opts['sku']                 = params['sku']
    opts['transmuter-hostaddr'] = params['dhcp-server']
    opts['swapsize']            = params['swapsize']
    opts['codename']            = params['codename'] 

    return transmuter.erb(:preseed , :locals => { :opts => opts })
  end

  # Render a URL that doesn't depend on state
  # @note called via /spell/render/ubuntu/boot
  # @note HTTP 400: missing required parameter
  # @note HTTP 409: iso requested to boot does not exist
  # @param [TransmuterHTTP] transmuter The Sinatra frontend to handle client interaction
  # @param [Hash] env Environment variables at the time of the request
  # @param settings Sinatra configuration settings for this spell
  # @param request Sinatra request object that this is rendering for
  # @todo look up more preseed options in collins
  def self.render_boot(transmuter,env,settings,request)

    transmuter.halt(400, "No sku specified") unless request.params.has_key? 'sku'
    transmuter.halt(400, "No iso specified") unless request.params.has_key? 'iso'
    transmuter.halt(400, "No mac specified") unless request.params.has_key? 'mac'
    iso = request.params['iso']
    sku = request.params['sku']
    mac = request.params['mac']
    transmuter.halt(409, "Requested iso does not exist") unless settings.has_key? 'ubuntu' and settings['ubuntu'].has_key? 'isos' and settings['ubuntu']['isos'].has_key? iso
    puts "Rendering ubuntu #{iso} boot for #{sku} with #{mac}"

    # todo try to look up swapsize in collins

    spec = settings['ubuntu']['isos'][iso]
    if request.params.has_key? 'swapsize'
      swapsize = request.params['swapsize']
      spec['swapsize'] = swapsize 
    else
      spec['swapsize'] = settings['ubuntu']['default_swap']
    end

    if request.params.has_key? 'netinterface' and request.params['netinterface'] == 'manual'
      spec['manual_interface'] = true
    end

    # https://lists.debian.org/debian-boot/2011/06/msg00226.html for how BOOTIF works
    spec['mac'] = "00:"+mac # this is really stupid, but it needs an extra 3 bytes specifying a bogus hardware type, which is skipped anyways
    return transmuter.erb(:ubuntu_boot, :locals => { :opts => spec, :sku => sku })
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
