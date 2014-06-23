# Upstream
require 'sinatra'
require 'sinatra/async'
require 'sinatra/config_file'
require 'yaml'

# Custom
require 'util'
require 'collins'

# Dynamically load spell code
$views   = ['views']
$spells = []
$menu_spells = {}
$spell_conf = {}

# Define the base directory
$base = File.dirname(File.dirname(File.expand_path(__FILE__)))

# Scan for spells and hotplug them
# Yes, this is ugly but it works. I'd be happy to get a PR on this.
Dir.foreach(File.join($base,'spells')) do | spell |
  next if spell == '.' or spell == '..'
  spell_path = File.join($base,'spells',spell)
  menu_conf  = File.join(spell_path,"menu.yml")
  spell_conf = File.join(spell_path,"#{spell}.yml")
  $spells.push(spell)

  if File.exist? menu_conf 
    puts "Adding menu for #{spell}"
    $menu_spells[spell] = YAML.load(File.open(menu_conf))
  end

  if File.exist? spell_conf 
    $spell_conf[spell] = spell_conf
  end

  $LOAD_PATH.unshift spell_path
  $views.push("spells/#{spell}")
  require spell
end


# HTTP interface / routes - main sinatra class.
class TransmuterHTTP < Sinatra::Base

  # We use async sinatra so that we can do work without blocking
  register Sinatra::Async
  register Sinatra::ConfigFile

  config_hash = {}

  # Load configs
  menu_config = "#{File.join($base,'config','menu.yml')}"
  config_file menu_config
  config_hash['menu'] = settings.menu

  # Dynamically detected config files (above) are hot loaded
  $spell_conf.each do | spell, config |
    config_file config
    config_hash[spell] = eval("settings.#{spell}")
  end

  # Override views lookup folder to include hotplugged
  set :views, $views

  # We hardcode showing exceptions to off
  # This is because we define our own exception handler below
  # see ( #handle_exception! )
  def initialize
    super()
    settings.show_exceptions = false
  end

  # threaded - False: Will take requests on the reactor thread
  #            True:  Will queue request for background thread
  configure do
    set :threaded, false
    puts server.respond_to? :threaded
  end

  # Requested by iPXE on boot, chains into /boot.
  # This enables us to customize what details we want iPXE to send us
  # The iPXE undionly.kpxe should contain an embedded script to call this URL
  aget '/' do
    body {erb :boot}
  end

  # Requested by iPXE, renders an boot menu.
  # Using the parameters, a sku is computed and looked up in Collins to decide what to do.
  # The default boot option can be overriden programattically here, otherwise fall back to bios boot.
  # @param [String] mac - SMBios attribute for current mac address
  # @param [String] serial - SMBios attribute for chassis serial
  # @param [String] product - SMBios attribute for chassis product
  # @param [String] manufacturer - SMBios attribute for manufacturer
  # @param [String] board-serial - SMBios attribute for motherboard serial
  # @param [String] board-product - SMBios attribute for motherboard product
  # @note HTTP 400: missing required parameter
  aget '/boot' do
    puts "Boot: Got these params: #{params}"

    halt(400,"Missing mac") unless params.has_key? 'mac'
    halt(400,"Missing serial") unless params.has_key? 'serial'
    halt(400,"Missing product") unless params.has_key? 'product'
    halt(400,"Missing manufacturer") unless params.has_key? 'manufacturer'
    halt(400,"Missing board-serial") unless params.has_key? 'board-serial'
    halt(400,"Missing board-product") unless params.has_key? 'board-product'

    opts = config_hash.clone
    sku = compute_sku(params['manufacturer'], params['serial'], params['board-serial'])
    opts['sku'] = sku

   # begin 
   #   puts "Asking collins"
   #   asset = @collins.getAsset(sku)
   #   puts "back from collins"
   # rescue
   #   puts "Couldn't connect to collins :("
   #   halt(500,"Can't connect to collins") 
   # end

   # if asset.nil?

   #     puts "Asset #{sku} is unknown, we'll make it"
   #     intake = IntakeSpell.new(
   #         :sku => sku
   #     )
   #     intake.save

   #     # Modify the options hash to set the default options in the menu
   #     opts['menu_default'] = "alchemy"
   #     opts['callback'] = "/spell/notify?sku=#{sku}&message=booted"

   # else
   #     puts "Asset #{sku} is known"
   #     puts asset

   #     # Check if there is a spell taking care of this
   #     running = Asset.first(:sku => sku) 

   #     if not running.nil?
   #       # If so, let it decide what it should do and potentially override boot options
   #       options = running.respond(opts)
   #     end
   # end

    # Render the iPXE boot menu
    puts opts['coreos']['builds']
    body {erb :menu, :locals => { :opts => opts, :spells => $menu_spells }}
  end

  # Cast new spell on an asset.
  # All extra params will also be passed to the spell for it to handle if it chooses.
  # @param [String] sku - SKU for the asset to cast the spell on
  # @param [String] spell - Spell to cast on the asset
  # @note HTTP 400: missing required parameter
  # @note HTTP 409: specified spell does not exist / is not loaded.
  aget '/spell/cast' do

    puts "got params #{params}"
    halt(400,"missing sku") unless params.has_key? 'sku'
    halt(400,"missing spell") unless params.has_key? 'spell'
    halt(409,"invalid spell") unless $spells.include? params['spell']


    opts = settings.menu
    spellname = "#{params['spell'].capitalize}Spell"
    sku = params['sku']

    opts['sku'] = sku

    asset = Asset.first(:sku => sku ) 

    if asset.nil?
      asset = Asset.new(
          :sku => sku
      )
      if asset.save
        puts "Saved"
      else
        asset.errors.each do |e| 
          puts e
        end 
      end
    end

    spell = eval(spellname).new( :sku => sku, :asset => asset.id )
    if spell.save
      puts "Saved"
    else
      spell.errors.each do |e| 
        puts e
      end 
    end

    asset.pushSpell(spell)

  end

  # Map notifications to spell jobs, and get appropriate response
  # @param [String] sku - SKU for the asset to cast the spell on
  # @param [String] message - Message to send to the spell
  # @note HTTP 400: missing required parameter
  # @note HTTP 409: there is no spell for specified asset, or there is no asset - nothing to notify.
  aget '/spell/notify' do

    halt(400,"missing sku") unless params.has_key? 'sku'
    halt(400,"missing message") unless params.has_key? 'message'

    puts "got params #{params}"

    sku      = params['sku']
    message  = params['message']

    asset = Asset.first(:sku => sku) 
    halt(409,"No knowledge of asset #{sku}") unless not asset.nil?

    spell = asset.getSpell
    halt(409,"No spells for asset #{sku}") unless not spell.nil?

    opts = settings.menu
    opts['sku'] = sku

    spell.notify(message)
    body { spell.respond( options ) }
  end

  # Dynamically map render requests to spells.
  # All extra paramaters are sent to the spell, so additional params may be required as enforced by spell render method.
  # @param [String] spell - URI param (see above regex), spell to notify
  # @param [String] render - URI param (see above regex), render method to call
  # @note HTTP 400: missing required parameter
  # @note HTTP 409: request is invalid - invalid spell or invalid render method.
  # @todo also allow this to route to instance methods, not just class methods.
  aget %r{/spell/render/(?<spell>\w*)/(?<render>\w*)} do
    halt(400,"missing spell name") unless params.has_key? 'spell'
    halt(400,"missing render method") unless params.has_key? 'render'

    # Very important to sanity check the params here/ because we are going to 'eval'.
    halt(409,"invalid spell") unless $spells.include? params['spell']
    spellname = "#{params['spell'].capitalize}Spell"

    # We make sure that the spell specified has a renderer
    halt(409,"spell #{spellname} doesn't implement render_#{params['render']}") unless eval(spellname).respond_to?("render_#{params['render']}")

      # Pass it off to the spell to render
    body {eval(spellname).method("render_#{params['render']}").call(self,@env,config_hash.clone,request)}
  end

  # A couple of default behaviors we've overridden in sinatra
  helpers do
    # Enable partial template rendering
    def partial (template, locals = {})
      erb(template, :layout => false, :locals => locals)
    end
    # Override template search directorys to add spells
    def find_template(views, name, engine, &block)
      Array(views).each { |v| super(v, name, engine, &block) }
    end

    # Define our asynchronous scheduling mechanism, could be anything
    # Chose EM.defer for simplicity
    # This powers our asynchronous requests, and keeps us from blocking the main thread.
    def native_async_schedule(&b)
      EM.defer(&b)
    end
    
    # Needed to properly catch exceptions in async threads
    def handle_exception!(context)
      if context.message == "Sinatra::NotFound"
        error_msg = "Resource #{request.path} does not exist"
        puts error_msg
        ahalt(404, error_msg)
      else
        puts context.message
        puts context.backtrace.join("\n")
        ahalt(500,"Uncaught exception occurred")
      end
    end
  end
end
