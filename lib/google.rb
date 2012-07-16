require 'oauth2'
require 'sinatra/base'
require 'pp'
require 'socket'

module Google

  class AuthServer
    
    @@client_id     = nil
    @@client_secret = nil
    
    def AuthServer.getAuthentifier port=4567
      
      auth   = Google::Authentifier.new( @@client_id, 
                                         @@client_secret,
                                         'http://localhost:4567/oauth2callback',
                                         'https://spreadsheets.google.com/feeds')
      
      server = TCPServer.open port
      loop do
        client  = server.accept
        data    = client.gets
        
        okhdr   = "HTTP/1.1 200 OK\r\nContent-Type: text/html;\r\n\r\n"
        array   = data.split ' '
        
        if array.first == 'GET'
          if array[1] == '/'
            client.puts "HTTP/1.1 303 See Other\r\nLocation: #{auth.authorize_url}\r\n\r\n"
          elsif array[1] =~ %r|^/oauth2callback|
            code = (array[1].split "?code=")[1]
            auth.set_code code
            client.puts okhdr
            client.puts "OK!!"
            return auth
          end
        end
        
        client.close
      end
    end
  end

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
  
  class Cell
    
    attr_reader   :row,:col
    attr_accessor :formula,:value
    
    def initialize entry, client
      @client   = client
      @json     = entry
      @row      = entry['gs$cell']['row'].to_i
      @col      = entry['gs$cell']['col'].to_i
      @formula  = entry['gs$cell']['inputValue']
      @value    = entry['gs$cell']['$t']
      @edit_uri = entry['link'].select{|link| link['rel'] == 'edit'}.first['href']
    end
    
    def edit_xml
<<-EOF
<entry xmlns="http://www.w3.org/2005/Atom"
    xmlns:gs="http://schemas.google.com/spreadsheets/2006">
  <id>#{@edit_uri}</id>
  <link rel="edit" type="application/atom+xml"
    href="#{@edit_uri}"/>
  <gs:cell row="#{@row}" col="#{@col}" inputValue="#{@formula}"/>
</entry>
EOF
    end
    
    def save #must probably change @edit_uri after save
      answer = @client.token.put @edit_uri, {:headers => {'Content-Type' => 'application/atom+xml'},
                                             :body    => edit_xml}
    end
    
    def to_s
      "[#{@row}:#{@col} - '#{@formula}', '#{@value}']"
    end
    
  end
  
  class Cells
    
    attr_reader :cells
    
    def initialize cells
      @cells = cells
    end
    
    def [] row, col
      cell = @cells[[row,col]]
    end
    
  end
  
  class Worksheet
    attr_reader :writable, :title, :row_count, :col_count
    def initialize entry, client
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
    
    def cells
      answer = @client.token.get(@cells_feed)
      table  = {}
      answer.parsed['feed']['entry'].each do |entry|
        cell = Cell.new entry, @client
        table[[cell.row,cell.col]] = cell
      end
      return Cells.new table
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
  
  class Spreadsheets
  
    def initialize authentifier
      @client = authentifier
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
  end

end