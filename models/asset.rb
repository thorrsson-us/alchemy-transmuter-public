require 'json'
require 'spell'

# Representation and model of an asset
class Asset
  include DataMapper::Resource
  property :id,          Serial
  property :sku,         String, :required => true
  property :spell_queue, String, :required => true, :default => '[]'
  property :active,      Integer, :required => true, :default => -1


  # Load spells for this asset into memory from database
  def loadSpells
    @spells = JSON.load(self.spell_queue)
  end


  # Try to get the active spell
  # @return [Spell] current active spell for this asset, or nil if none active.
  def getSpell
    old_active = self.active
    if self.active > -1
      spell = Spell.get(self.active)
    else
      spell = nil
    end

    # If there is no active spell, or the active spell is done
    # We want to get the next spell
    if spell.nil? 
      spell = shiftSpell
    elsif not spell.nil? and spell.state == DONE
      spell.cleanup
      spell = shiftSpell
    end

    if spell.nil?
      self.active = -1
      puts "No spell for #{@id} in #{@spells}" 
    else
      self.active = spell.id
      if self.active != old_active
        puts "Active spell for asset #{@id} is #{self.active}"
      end
    end
    self.save
    return spell
  end


  # Add a spell to this asset's queue
  # @param [Spell] spell the spell to cast on this asset
  def pushSpell(spell)
    loadSpells
    @spells.push(spell.id)
    self.spell_queue = JSON.dump(@spells)
    save

    puts "Added new spell #{spell.id} to queue for Asset #{@id}: #{self.spell_queue}"
    
  end

  # Grab the next spell to run for this asset.
  # @return [Spell] the next spell to run for this asset, or nil if there is none.
  def shiftSpell
    loadSpells
    next_spell = @spells.shift
    save

    if next_spell.nil?
      spell = nil
    else
      spell = Spell.get(next_spell) 
    end

    return spell
  end

end
