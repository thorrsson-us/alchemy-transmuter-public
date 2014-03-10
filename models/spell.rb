require 'data_mapper'

NOT_STARTED = -1
DONE        = 0 # completed successfully
STARTED     = 1

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
  def cast
    raise 'All spells must implement a cast method'
  end

  # Allows for servers being transmuted to communicate with the spell about their progress
  def notify(message)
    raise 'All spells must implement a notify method, to receive updates from the transmuter'
  end

  # How to respond when receiving a notify, can vary based on state
  def respond(options = {})
    raise 'All spells must implement a respond method, to respond to updates from transmuter'
  end

  def updateTimeActive(step)
    self.time_active += step
    self.save
  end

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

  def getState
    @state = Spell.get(@id).state
  end

  def cleanup
    self.destroy()
  end

  def addBackend(backend)
    @collins = backend 
  end

  def addFrontend(frontend)
    @frontend = frontend
  end

end
