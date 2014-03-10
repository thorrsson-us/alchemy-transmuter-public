
require 'httparty'
require 'sinatra/base'
require 'json'

class Collins
  include HTTParty


  def initialize(settings)
    puts settings.collins
    self.class.base_uri settings.collins["hostname"]
    self.class.basic_auth settings.collins["username"], settings.collins["password"]
  end

  def post(text)
    #options = { :body => {:status => text}, :basic_auth => @auth }
    #self.class.post('/statuses/update.json', options)
  end

  def getAsset(sku)

    response = self.class.get("/api/asset/#{sku}")

    data = nil

    if response.code == 200
      data = JSON.parse(response.body)['data']['ASSET']
    elsif response.code == 401 
      data = false
    else
      puts response.code
    end
    puts data

    return data
  end

  # get unabridged asset data from Collins
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
    puts data

    return data
  end

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



