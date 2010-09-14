require 'rubygems'
require 'sinatra'

set :sessions, true

configure :production do
  set :show_exceptions, false
  # TODO: instead of exceptions, show a nicer error message.
end

get '/' do
  redirect '/login'
end

get '/login' do
  erb :login
end
