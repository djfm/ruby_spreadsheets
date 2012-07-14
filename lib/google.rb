require 'oauth2'
require 'sinatra/base'
require 'pp'

module Google

  class Authentifier
    attr_reader :token
  
    def initialize client_id, client_secret, redirect_uri, scope
    
      @client = OAuth2::Client.new(client_id,
                                   client_secret,
                                   :site => 'https://accounts.google.com',
                                   :token_url => '/o/oauth2/token',
                                   :authorize_url => '/o/oauth2/auth')
      
      @redirect_uri = redirect_uri
      @scope        = scope                    
    end
    
    def set_code code
      @token = @client.auth_code.get_token(code,
                                           :redirect_uri => 'http://localhost:4567/oauth2callback')
    end
    
    def authorize_url
      @client.auth_code.authorize_url(:redirect_uri => @redirect_uri, :scope => @scope)
    end
  end
  
  class Worksheet
    attr_reader :writable, :title, :row_count, :col_count
    def initialize entry, client
      pp entry
      @client = client
      @title  = entry['title']['$t']
      @cells_rel  = 'http://schemas.google.com/spreadsheets/2006#cellsfeed'
      @cells_feed = entry['link']
                    .select{|link| link['rel'] == @cells_rel}
                    .first['href'] + '?alt=json'
      @writable = !!(@cells_feed =~ %r|/private/full|)
      @row_count = entry['gs$rowCount']['$t'].to_i
      @col_count = entry['gs$colCount']['$t'].to_i
    end
    
    def to_s
      "#{@title} (#{@row_count} rows and #{@col_count} columns, #{@writable?'writable':'readonly'})"
    end
    
  end
  
  class Spreadsheet
    attr_reader :writable, :title
    def initialize entry, client
      @client = client
      @worksheets_rel  = 'http://schemas.google.com/spreadsheets/2006#tablesfeed'
      @worksheets_feed = entry['link']
                        .select{|link| link['rel'] = @worksheets_rel}
                        .first['href']+'?alt=json'
      @writable = !!(@worksheets_feed =~ %r|/private/full|)
      @title = entry['title']['$t'];
    end
    
    def worksheets
      answer = @client.token.get @worksheets_feed
      answer.parsed['feed']['entry'].map do |entry|
        Worksheet.new entry, @client
      end
    end
    
    def to_s
      "#{@title} (#{@writable?'writable':'readonly'}) : #{worksheets.join(',')}"
    end
    
  end
  
  class Spreadsheets < Sinatra::Base
  
    def initialize
      super
      @client = Google::Authentifier.new( settings.client_id, 
                                          settings.client_secret,
                                          'http://localhost:4567/oauth2callback',
                                          'https://spreadsheets.google.com/feeds')
    end
    
    def css name
      "<link rel='stylesheet' type='text/css' href='/css/#{name}.css'></link>"
    end
    
    def spreadsheets filter=nil
      answer = @client.token.get('https://spreadsheets.google.com/feeds/spreadsheets/private/full?alt=json')
      answer.parsed['feed']['entry']
            .select{|entry| 
                case filter
                  when NilClass then true
                  when Regexp then entry['title']['$t'] =~ filter
                  when String then entry['title']['$t'] == filter
                 end
            }
            .map{|entry| Spreadsheet.new entry, @client}
    end
    
    get '/' do
      erb :auth, :locals => {:authorize_url => @client.authorize_url}
    end
    
    get '/oauth2callback' do
        @client.set_code params[:code]
        redirect '/menu'
    end
    
    get '/menu' do
      erb :menu
      html = ''
      spreadsheets('RUBYTEST').each do |spreadsheet|
        html += "<p>#{spreadsheet}</p>"
        spreadsheet.worksheets
      end
      html
    end
    
  end

end