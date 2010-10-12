# Copyright 2010 Bob.sh

require 'rubygems'
require 'sinatra'
require 'id.rb'

def app
  Id
end

map "/" do
  run Id
end
