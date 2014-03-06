require 'sinatra'

get '/' do
  name = params[:name]
  erb :preseed, :locals => { :foo => name }
end
