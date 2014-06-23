require 'data_mapper'
require 'yaml'

require 'collins'

# spell hasn't been casted yet
NOT_STARTED = -1

# completed successfully
DONE        = 0

# spell has been casted
STARTED     = 1

# "Abstract" spell class
# Provides the representation, model, and interface of a "Spell"
# @abstract Subclass and override {#cast}, {#notify}, and {#respond}
class Spell
  include DataMapper::Resource
  property :id,          Serial
  property :type,        Discriminator # needed in order to have subclassing
  property :asset,       Integer, :required => true
  property :sku,         String, :required => true
  property :state,       Integer, :required => true, :default => NOT_STARTED
  property :time_active, Integer, :required => true, :default => 0
  property :params,      String, :required => true, :default => '[]'

  # The run method initializes the state, and handles state transitioning
  # @abstract This is just an interface, don't use it directly.
  def cast
    raise 'All spells must implement a cast method'
  end

  # Allows for servers being transmuted to communicate with the spell about their progress
  # @param [String] message The message to send to the spell
  # @abstract This is just an interface, don't use it directly.
  def notify(message)
    raise 'All spells must implement a notify method, to receive updates from the transmuter'
  end

  # Respond when receiving a message, can vary based on state
  # @param [Hash] options The options passed via http
  # @abstract This is just an interface, don't use it directly.
  def respond(options = {})
    raise 'All spells must implement a respond method, to respond to updates from transmuter'
  end

  # Update how long this spell has been active for
  # @param [Integer] step the interval to increment time active by.
  def updateTimeActive(step)
    self.time_active += step
    self.save
  end

  # Update the state of this spell
  # @param [Integer] newState The new state of this spell. 
  def updateState(newState)
    self.state = newState
    if self.save
      puts "Updated state to #{@state}"
    else
      self.errors.each do |e| 
        puts e
      end 
    end
  end

  # Get the state of this spell
  # @return [Integer] the state of the asset.
  def getState
    @state = Spell.get(@id).state
  end

  # Destroy this spell instance from the database
  def cleanup
    self.destroy()
  end

  # Attach a sinatra frontend to this asset, so it can respond.
  # @param [TransmuterHTTP] frontend - The frontend to attach
  def addFrontend(frontend)
    @frontend = frontend
  end

  # Provides a handle to collins
  # @return [Collins] an instance of collins httparty interface
  def self.getCollins
    return Collins.new
  end
end
