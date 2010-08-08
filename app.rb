require 'rubygems'
require 'sinatra'
require 'digest/md5'
require 'json'
require 'rest_client'

require 'haml'
require 'oauth2'

config = YAML.load_file(File.join(File.dirname(__FILE__), 'facebook.yml'))

APP_ID = config['app_id']
APP_SECRET = config['app_secret']

puts ".#{APP_SECRET}."

get '/' do
  if session['access_token']
    @access_token = OAuth2::AccessToken.new(client, session['access_token'])
  elsif @facebook_data = facebook_cookie(request.cookies["fbs_#{APP_ID}"])
    @access_token = OAuth2::AccessToken.new(client, @facebook_data['access_token'])
  end
  
  @app_id = APP_ID
  if @access_token
    @graph = JSON.parse(@access_token.get("/me"))
    @friends = JSON.parse(@access_token.get("/me/friends"))
  end
  haml :index
end

def facebook_cookie(cookie)
  return if cookie.nil?
  cleaned_cookie = 
  vars = Rack::Utils.parse_nested_query(cookie.sub(/^"(.*)"/,"\\1"))
  sig = vars.delete("sig")
  payload = vars.to_a.sort_by{|a| a.first }.map{|e| "#{e.first}=#{e.last}" }.join("")
  if  Digest::MD5.hexdigest(payload + APP_SECRET) != sig
    return nil;
  else
    return vars;
  end
end


def client
  OAuth2::Client.new(APP_ID, APP_SECRET, :site => 'https://graph.facebook.com')
end

get '/auth/facebook' do
  redirect client.web_server.authorize_url(
    :redirect_uri => redirect_uri,
    :scope => 'email,user_birthday'
  )
end

get '/auth/facebook/callback' do
  access_token = client.web_server.get_access_token(params[:code], :redirect_uri => redirect_uri)
  redirect "/"
  user = JSON.parse(access_token.get('/me'))
  session['access_token'] = access_token
  user.inspect
end

def redirect_uri
  uri = URI.parse(request.url)
  uri.path = '/auth/facebook/callback'
  uri.query = nil
  uri.to_s
end
