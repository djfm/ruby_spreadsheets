#!/usr/bin/ruby

require_relative 'lib/google'
require_relative 'config'

auth = Google::AuthServer.getAuthentifier

spreadsheets = Google::Spreadsheets.new auth

cells = (spreadsheets.spreadsheets 'RUBYTEST').first.worksheets.first.cells

cells[1,1].formula = 'coucou'
cells[1,1].save
cells[1,2].formula = 'lol'
cells[1,2].save
cells[1,2].formula = 'test'
cells[1,2].save
