require 'spell'
require 'asset'
require 'collins'

# Runs spells that have been queued up
class SpellCaster

  # Set up references to frontend, and interval to poll for spells to cast
  def initialize(interval, frontend)
    @interval = interval
    @frontend = frontend 
    @casting = false
  end

  # Start casting spells
  # @todo properly handle timeouts and restart spells
  def start

    unless @casting
      Spell.all.each do |spell|
        spell.addFrontend(@frontend)
      end
    
      EM.add_periodic_timer(@interval) do
        # Check for unassigned tasks
        puts "Checking assets for spells"
    
        Asset.all.each do |asset|
          spell = asset.getSpell
          next if spell.nil?

          spell.updateTimeActive(@interval)

          # Cast new spells
          if spell.state < STARTED 
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
