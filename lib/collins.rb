
require 'httparty'
require 'sinatra/base'
require 'json'
require 'yaml'
require 'sinatra/config_file'

$collins_config = "#{File.join(File.dirname(File.dirname(File.expand_path(__FILE__))),'config','collins.yml')}"
puts $collins_config

# Interface with the Collins server
class Collins 
  include HTTParty
  config = YAML.load_file($collins_config)['collins']
  base_uri config["hostname"]
  basic_auth config["username"], config["password"]

  # Load an asset by SKU
  # @param [String] sku for the server to look up
  # @return [Hash]  hash of JSON asset data for server from collins, or nil if not found
  def getAsset(sku)

    asset = nil
    data = getFullAssetData(sku)
    if not data.nil?
      asset = data['ASSET']
    end

    return asset
  end

  # Get all attributes associated with an asset
  # @param [String] sku for the server to look up
  # @return [Hash]  hash of all JSON attribute data for server from collins, or nil if not found
  def getFullAssetData(sku)

    response = self.class.get("/api/asset/#{sku}")
    data = nil

    if response.code == 200
      data = JSON.parse(response.body)['data']
    elsif response.code == 401
      data = false
    else
      puts response.code
    end

    return data
  end

  # Create an asset in collins if there is no existing asset
  # @param [String] sku for the server to create
  # @return [Hash]  hash of all JSON asset data for server from collins
  def createIfNotExists(sku)

    response = self.class.get("/api/asset/#{sku}")
    data = nil

    if response.code == 200
      # asset already exists
      data = JSON.parse(response.body)['data']['ASSET']

    else
      response = self.class.put("/api/asset/#{sku}", { :body => {'generate_ipmi' => true, 
                                                      'type'          => 'SERVER_NODE'
                                                     }} )
      if response.code == 201
        data = JSON.parse(response.body)['data']['ASSET']
      end
    end
    return data
  end

  # Update log in collins for a given asset
  # @param [String] sku for the server to provide log data
  # @param [String] message to add to the log
  # @param [String] level of log data, from: 'EMERGENCY','ALERT','CRITICAL','ERROR','WARNING','NOTICE','INFORMATIONAL','DEBUG','NOTE', default is INFORMATIONAL
  def updateLog(sku, message, level=nil)

    # Available levels are:
    levels = [ 'EMERGENCY','ALERT','CRITICAL','ERROR','WARNING','NOTICE','INFORMATIONAL','DEBUG','NOTE' ]

    if level.nil? or not levels.include? level
      level = 'INFORMATIONAL'
    end
    puts "updating log, #{message}"
    response = self.class.put("/api/asset/#{sku}/log", { :body => {'message' => message, 'type' => level} })

    if response.code == 201
      puts "log created"
      puts response.body 
    else

      puts "log failed"
      puts response.body 
    end
  end
end
