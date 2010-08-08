require 'rubygems'
require 'sinatra'
require 'digest/md5'
require 'json'
require 'rest_client'
require 'oauth2'
config = YAML.load_file(File.join(File.dirname(__FILE__), 'facebook.yml'))

APP_ID = config['app_id']
APP_SECRET = config['app_secret']

before do
  content_type :html, 'charset' => 'utf-8'
end

get '/auth/facebook' do
  redirect client.web_server.authorize_url(
    :redirect_uri => redirect_uri,
    :scope => 'email,user_birthday,publish_stream'
  )
end

get '/auth/facebook/callback' do
  access_token = client.web_server.get_access_token(params[:code], :redirect_uri => redirect_uri)
  redirect "/"
  user = JSON.parse(access_token.get('/me'))
  session['access_token'] = access_token
  user.inspect
end

post '/post' do
  if @access_token = access_token
    @access_token.post("/me/feed", {:message => params[:message]})
  end
  redirect '/'
end

get '/' do
  if @access_token = access_token
    begin
      @graph = JSON.parse(@access_token.get("/me"))
      @friends = JSON.parse(@access_token.get("/me/friends"))
    rescue => e
      @facebook_data = @graph = @friends = nil
    end
  end
  haml :index
end

def client
  OAuth2::Client.new(APP_ID, APP_SECRET, :site => 'https://graph.facebook.com')
end

def redirect_uri
  uri = URI.parse(request.url)
  uri.path = '/auth/facebook/callback'
  uri.query = nil
  uri.to_s
end

def facebook_cookie(cookie)
  vars = Rack::Utils.parse_nested_query(cookie)
  sig = vars.delete("sig")
  payload = vars.to_a.sort_by{|a| a.first }.map{|e| "#{e.first}=#{e.last}" }.join("")
  if  Digest::MD5.hexdigest(payload + APP_SECRET) != sig
    return nil;
  else
    return vars;
  end
end

def access_token
  @facebook_data = facebook_cookie(request.cookies["fbs_#{APP_ID}"]) || {}
  access_token = session['access_token'] || @facebook_data['access_token']
  OAuth2::AccessToken.new(client, access_token)
end