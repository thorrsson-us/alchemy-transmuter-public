require 'spell'

# Spell to perform server intake
class IntakeSpell < Spell

  @@WAIT_BOOT     = 2 # waiting for server to boot
  @@BOOTED        = 3 # server is booted
  @@WAIT_DATA     = 4 # waiting for server to send intake data

  # The run method initializes the state, and handles state transitioning
  def cast
    if @state == STARTED
        # Create the asset
        @collins.createIfNotExists(@sku)
        updateState( @@WAIT_BOOT )
        @collins.updateLog(@sku, 'Waiting for asset to boot')
    end
  end

  # Allows for servers being transmuted to communicate with the spell about their progress
  # @param [String] message The message to send to the spell
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

  # Respond when receiving a message, can vary based on state
  # @param [Hash] options The options passed via http
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
