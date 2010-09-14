require 'rubygems'
require 'sinatra'

enable :sessions

get '/' do
  redirect '/login'
end

get '/login' do
  'Hello world!'
end
