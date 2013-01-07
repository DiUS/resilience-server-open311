<<<<<<< HEAD
require 'rubygems'
require 'bundler'

Bundler.require

require './resilience-server.rb'
run App
=======
# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
run ResilienceServer::Application
>>>>>>> 422191c8255036b46511c2031e55f5f742af0c25
