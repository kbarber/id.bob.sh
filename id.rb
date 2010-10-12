#!/usr/bin/env ruby
# Copyright 2010 Bob.sh
#
# Main sinatra application
#

require 'rubygems'
require 'sinatra/base'
require 'sinatra/captcha'
require 'crowd'
require 'yaml'
require 'pp'

# Load configuration
CONF = YAML.load_file("/etc/www/id.bob.sh/config.yaml")

class Id < Sinatra::Base
  helpers Sinatra::Captcha
  
  # Configure rack sessions
  use Rack::Session::Memcache,	:key => CONF["rack"]["cookie_key"],
                                :secret => CONF["rack"]["cookie_secret"]
  
  # Prepare crowd
  Crowd.crowd_url = CONF["crowd"]["url"]
  Crowd.crowd_app_name = CONF["crowd"]["app_name"]
  Crowd.crowd_app_pword = CONF["crowd"]["app_pword"]
  Crowd.authenticate_application
  
  # Configure application differently for production use
  configure :production do
    set :show_exceptions, false
    # TODO: instead of exceptions, show a nicer error message.
  end
  
  before do
  
    # First lets try to establish any prior SSO authentication using crowd.token_key
    # and looking at our existing sessions.
  
    crowd_token = request.cookies["crowd.token_key"]
  
    # If a crowd token is set, and either the username isn't set or 
    # the cookie crowd.token_key doesn't match the session crowd_token
    # then lets do a revalidation
    if crowd_token and (
        !session.key?(:username) or
        !session.key?(:crowd_token) or
        (crowd_token != session[:crowd_token])
      ) then
  
      # Find principal and check if its real
      crowd_principal = Crowd.find_principal_by_token(crowd_token)
      if crowd_principal == nil then
        # No such principal, or its expired. Clear the cookie and redirect.
        response.delete_cookie("crowd.token_key", {
          :domain => CONF["crowd"]["domain"],
          :path => "/" })
        redirect '/login'
      end
       
      # So lets set the session up properly
      session[:username] = crowd_principal["name"]
      session[:crowd_token] = crowd_token
    end
  
    # Now lets apply any filtering.
  
    # Check if the session is authenticated (ie. username is set) otherwise send
    # the user back to /login.
    if !session.key?(:username) and request.path_info !~ /^\/(log(out|in)|register)/ then
      redirect '/login'
    end
  end
  
  get '/' do
    redirect '/me'
  end
  
  get '/login' do
    erb :login
  end
  
  post '/login' do
    username = params[:username]
    password = params[:password]
  
    begin
      # Authenticate principal with Crowd
      token = Crowd.authenticate_principal(username,password,{
        'User-Agent' => request.env["HTTP_USER_AGENT"],
        'remote_address' => request.env["REMOTE_ADDR"]
      })
  
      # Set cookie for crowd SSO
      response.set_cookie("crowd.token_key", {
        :value => token,
        :domain => CONF["crowd"]["domain"],
        :path => "/" })
  
      session[:username] = username
      session[:crowd_token] = token
  
      redirect '/me'
    rescue Crowd::AuthenticationException
      erb :login
    end
  end
  
  get '/me' do
    # Grab a few Crowd vars for the user for populating their profile page
    @crowd_token = request.cookies["crowd.token_key"]
    @crowd_principal = Crowd.find_principal_by_token(@crowd_token)
    erb :me
  end
  
  get '/logout' do
    # TODO: this is fairly unclean and doesn't deal with the token key
    # stored in the session.
  
    # Grab the token and invalidate it on the crowd side
    crowd_token = request.cookies["crowd.token_key"]
    Crowd.invalidate_principal_token(crowd_token)
  
    # Delete the cookie to invalidate the client on other SSO sites
    response.delete_cookie("crowd.token_key", {
      :domain => CONF["crowd"]["domain"],
      :path => "/" })
  
    # Remove session data
    session.delete(:username)
    redirect '/'
  end
  
  get '/register' do
    erb :register
  end
  
  post '/register' do
    halt(401, "Invalid catpcha") unless captcha_pass?
    # Gather params
    firstname = params[:firstname]
    lastname = params[:lastname]
    username = params[:username]
    password = params[:password]
    email = params[:email]
  
    # Do the thing ...
    Crowd.add_principal(username, password, "", true, { 
      'mail' => email, 
      'givenName' => firstname, 
      'sn' => lastname })
  
    # TODO: currently we don't really validate before creation. We probably
    # should.
    'Registration complete. <a href="/login">Login</a>.'
  end
end

# vim: ts=2 sw=2 expandtab:
