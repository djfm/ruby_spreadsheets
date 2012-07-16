#!/usr/bin/ruby

require_relative 'lib/google'
require_relative 'config'

auth = Google::AuthServer.getAuthentifier

spreadsheets = Google::Spreadsheets.new auth

puts spreadsheets.spreadsheets 'RUBYTEST'
