#!/usr/bin/env ruby
# Copyright 2010 Bob.sh
#
# Main sinatra application
#

require 'rubygems'
require 'sinatra'

# TODO: make the secret a configuration item
use Rack::Session::Memcache,	:key => 'rack.session',
                              :secret => 'change_me'

configure :production do
  set :show_exceptions, false
  # TODO: instead of exceptions, show a nicer error message.
end

before do
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

  if password == "password" then
    session[:username] = username
    redirect '/me'
  else
    erb :login
  end
end

get '/me' do
  erb :me
end

get '/logout' do
  session.delete(:username)
  redirect '/'
end

get '/register' do
  erb :register
end

post '/register' do
  'Check your email and click on the link inside'
end

# vim: ts=2 sw=2 expandtab:
