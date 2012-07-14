#!/usr/bin/ruby

require_relative 'lib/google'
require_relative 'config'

Google::Spreadsheets.set :app_file, File.dirname(__FILE__)

class Stats < Google::Spreadsheets
  def after_authentication
    html = ''
    spreadsheets('RUBYTEST').first.worksheets.first.cells.each_pair do |coords,cell|
      html += "<p>#{coords} -  #{cell}</p>"
    end
    html
  end
end

Stats.run!
