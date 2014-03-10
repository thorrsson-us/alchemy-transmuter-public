require 'json'
require 'spell'

class Asset
  include DataMapper::Resource
  property :id,          Serial
  property :sku,         String, :required => true
  property :spell_queue, String, :required => true, :default => '[]'
  property :active,      Integer, :required => true, :default => -1


  def loadSpells
    @spells = JSON.load(self.spell_queue)
  end

  def getSpell
    # Try to get the active spell
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

  def pushSpell(spell)
    loadSpells
    @spells.push(spell.id)
    self.spell_queue = JSON.dump(@spells)
    save

    puts "Added new spell #{spell.id} to queue for Asset #{@id}: #{self.spell_queue}"
    
  end

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
