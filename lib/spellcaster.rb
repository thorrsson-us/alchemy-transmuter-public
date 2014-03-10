require 'spell'
require 'asset'

class SpellCaster
  $collins = nil

  def initialize(interval, backend, frontend)

    @interval = interval
    @backend = backend 
    @frontend = frontend 
    @casting = false

  end


  def start

    unless @casting
      Spell.all.each do |spell|
        spell.addBackend(@backend)
        spell.addFrontend(@frontend)
      end
    
      EM.add_periodic_timer(@interval) do
        # Check for unassigned tasks
        puts "Checking assets for spells"
    
        Asset.all.each do |asset|
          spell = asset.getSpell
          next if spell.nil?

          spell.updateTimeActive(@interval)

          #TO DO: handle timeouts here

          # Cast new spells
          if spell.state < STARTED 
            spell.addBackend(@backend)
            puts "Casting #{spell.class} on #{spell.sku}"
            spell.updateState( STARTED )
            spell.save                                                     
            EM.defer do 
              spell.cast
            end
          end
        end
      end
    end
  end
end
