# Upstream
require 'sinatra'
require 'yaml'

# Custom
require 'util'
require 'collins'

# Dynamically load spell code
$views  = ['views']
$spells = {}

base = File.dirname(File.dirname(File.expand_path(__FILE__)))
Dir.foreach(File.join(base,'spells')) do | spell |
  next if spell == '.' or spell == '..'
  spell_path = File.join(base,'spells',spell)
  spell_conf = File.join(spell_path,"#{spell}.yml")

  if File.exist? spell_conf 
    $spells[spell] = YAML::load(File.open(spell_conf)) # replace this with a spell config file for safety checking
  else
    puts "Warning: #{spell} has no config, it's probably going to be ignored"
  end

  $LOAD_PATH.unshift spell_path
  $views.push("spells/#{spell}")
  require spell
end

class TransmuterHTTP < Sinatra::Base

  # Override views lookup folder with dynamically generated
  set :views, $views

  def initialize(settings)

    @settings = settings
    @collins = Collins.new(settings)

    interval = @settings.main['interval']  # '120'
    caster = SpellCaster.new(interval, @collins, self)
    caster.start
    super()
  end

  def get_settings
    return @settings
  end

  # threaded - False: Will take requests on the reactor thread
  #            True:  Will queue request for background thread
  configure do
    set :threaded, false
  end

  # Requested by iPXE on boot, chains into /boot.
  # This enables us to customize what we want from iPXE
  get '/' do
    erb :boot 
  end

  # Requested by iPXE, should give us a number of parameters to decide what to do
  get '/boot' do
    puts "Boot: Got these params: #{params}"

    halt(400,"Missing serial") unless params.has_key? 'serial'
    halt(400,"Missing mac") unless params.has_key? 'mac'
    halt(400,"Missing product") unless params.has_key? 'product'
    halt(400,"Missing manufacturer") unless params.has_key? 'manufacturer'
    halt(400,"Missing board-serial") unless params.has_key? 'board-serial'
    halt(400,"Missing board-product") unless params.has_key? 'board-product'

    opts = @settings.options.clone

    sku = compute_sku(params)
    opts['sku'] = sku

    begin 
      puts "Asking collins"
      asset = @collins.getAsset(sku)
      puts "back from collins"
    rescue
      puts "Couldn't connect to collins :("
      halt(500,"Can't connect to collins") 
    end

    if asset or asset.nil?
      if asset.nil?

          # New server, add intake spell to options hash and render menu, telling alchemy to bring'r'in
          puts "Asset #{sku} is unknown, we'll make it"
          intake = IntakeSpell.new(
              :sku => sku
          )
          intake.save

          # Modify the options hash to set the default options in the menu
          opts['menu_default'] = "alchemy"
          opts['callback'] = "/spell/notify?sku=#{sku}&message=booted"

      else
          puts "Asset #{sku} is known"
          puts asset

          # Check if there is a spell taking care of this
          running = Asset.first(:sku => sku) 

          if not running.nil?
            # If so, let it decide what it should do and potentially override boot options
            options = running.respond(options)
          end
      end
    else
      puts "Invalid login"
    end

    # Render the iPXE boot menu
    erb :menu, :locals => { :opts => opts, :spells => $spells }
  end

  # Cast new spell on an asset
  get '/spell/cast' do

    puts "got params #{params}"

    halt(400,"missing sku") unless params.has_key? 'sku'
    halt(400,"missing spell") unless params.has_key? 'spell'
    halt(409,"invalid spell") unless $spells.has_key? params['spell']
    
    options = @settings.options.clone
    spellname = "#{params['spell'].capitalize}Spell"
    sku = params['sku']

    options['sku'] = sku

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
    spell.addBackend(@collins)
    spell.addFrontend(self)
    spell.cast
    spell.respond(options)

  end

  # Map notifications to spell jobs, and get appropriate response
  get '/spell/notify' do

    puts "got params #{params}"

    halt(400,"missing sku") unless params.has_key? 'sku'
    halt(400,"missing message") unless params.has_key? 'message'
    
    sku      = params['sku']
    message  = params['message']

    asset = Asset.first(:sku => sku) 
    halt(409,"No knowledge of asset #{sku}") unless not asset.nil?

    spell = asset.getSpell
    halt(409,"No spells for asset #{sku}") unless not spell.nil?


    options = @settings.options.clone
    options['sku'] = sku

    spell.notify(message)
    response = spell.respond( options )
    return response

  end

  # Dynamically map render requests to spells
  get %r{/spell/render/(?<spell>\w*)/(?<render>\w*)} do

    halt(400,"missing spell name") unless params.has_key? 'spell'
    halt(400,"missing render method") unless params.has_key? 'render'

    # Very important to sanity check the params here, because we are going to 'eval'.
    halt(409,"invalid spell") unless $spells.has_key? params['spell']
    spellname = "#{params['spell'].capitalize}Spell"

    # We make sure that the spell specified has a renderer
    halt(409,"spell #{spellname} doesn't implement render_#{params['render']}") unless eval(spellname).respond_to?("render_#{params['render']}")

    # Pass it off to the spell to render
    return eval(spellname).method("render_#{params['render']}").call(self,@env,@settings,request)

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
  end
end
