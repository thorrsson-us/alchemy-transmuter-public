require 'spell'

class IntakeSpell < Spell

  @@WAIT_BOOT     = 2 # waiting for server to boot
  @@BOOTED        = 3 # server is booted
  @@WAIT_DATA     = 4 # waiting for server to send intake data

  def cast
    if @state == STARTED
        # Create the asset
        @collins.createIfNotExists(@sku)
        updateState( @@WAIT_BOOT )
        @collins.updateLog(@sku, 'Waiting for asset to boot')
    end
  end

  # Can only really update state
  def notify(message)

    puts "Got message #{message}"
    case message
      when "booted"
        puts "Server booted"
        updateState( @@BOOTED )
        @collins.updateLog(@sku, 'Asset booted, collecting intake data')

      when "data_done"
        puts "Data updated"
        updateState( @@BURNIN_START ) 
        @collins.updateLog(@sku, 'Intake data received')
    end
  end

  # Can only really respond based on state
  def respond(options = {})

    
    puts "Responding in state #{@state}"
    case @state
      when @@BOOTED
        updateState( @@WAIT_DATA )

        #set options for intake.erb template to render
        options[:template] = :intake
    end

    return options
  end
end
