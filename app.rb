require 'rubygems'
require 'sinatra'
require 'digest/md5'
require 'json'
require 'rest_client'

config = YAML.load_file(File.join(File.dirname(__FILE__), 'facebook.yml'))

APP_ID = config['app_id']
APP_SECRET = config['app_secret']

get '/' do
  @facebook_data = facebook_cookie(request.cookies["fbs_#{APP_ID}"])
  if @facebook_data
    @graph = JSON.parse(RestClient.get("https://graph.facebook.com/me?access_token=#{Rack::Utils.escape(@facebook_data['access_token'])}"))
    @friends = JSON.parse(RestClient.get("https://graph.facebook.com/me/friends?access_token=#{Rack::Utils.escape(@facebook_data['access_token'])}"))
  end
  haml :index
end

def facebook_cookie(cookie)
  vars = Rack::Utils.parse_nested_query(cookie)
  sig = vars.delete("sig")
  payload = vars.to_a.sort_by{|a| a.first }.map{|e| "#{e.first}=#{e.last}" }.join("")
  puts Digest::MD5.hexdigest(payload + APP_SECRET)
  if  Digest::MD5.hexdigest(payload + APP_SECRET) != sig
    return nil;
  else
    return vars;
  end
end
