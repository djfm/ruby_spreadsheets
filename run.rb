#!/usr/bin/ruby

require_relative 'lib/google'
require_relative 'config'

Google::Spreadsheets.set :app_file, File.dirname(__FILE__)

class Stats < Google::Spreadsheets
  def after_authentication
    html = ''
    cells = spreadsheets('RUBYTEST').first.worksheets.first.cells
    cells.each_pair do |coords,cell|
      html += "<p>#{coords} -  #{cell}</p>"
    end
    cells[[1,1]].formula = 'AGAIN TEST CHANGE VALUE'
    cells[[1,1]].save
    cells[[1,1]].formula = 'yayp!'
    cells[[1,1]].save
    html
  end
end

Stats.run!
