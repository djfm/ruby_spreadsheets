#!/usr/bin/ruby

require_relative 'lib/google'
require_relative 'config'

Google::Spreadsheets.set :app_file, File.dirname(__FILE__)

Google::Spreadsheets.run!
