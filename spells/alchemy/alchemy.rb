require 'spell'

# Render menu options for Alchemy Linux
# @note this doesn't do any stateful management, so this class doesn't have to be instantiated.
class AlchemySpell < Spell

  # Render a URL that doesn't depend on state
  # @note called via /spell/render/alchemy/boot
  # @note HTTP 400: missing required parameter
  # @param [TransmuterHTTP] transmuter The Sinatra frontend to handle client interaction
  # @param [Hash] env Environment variables at the time of the request
  # @param settings Sinatra configuration settings for this spell
  # @param request Sinatra request object that this is rendering for
  def self.render_boot(transmuter,env,settings,request)
    
    opts = settings['alchemy']
    return transmuter.erb(:alchemy_boot , :locals => { :opts => opts })
  end

  # The run method initializes the state, and handles state transitioning
  def cast
  end

  # Allows for servers being transmuted to communicate with the spell about their progress
  # @param [String] message The message to send to the spell
  def notify(message)
    puts "Got message #{message}"
  end

  # Respond when receiving a message, can vary based on state
  # @param [Hash] options The options passed via http
  def respond(options = {})
    puts "Responding in state #{@state}"
  end

end
