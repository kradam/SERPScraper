#!/usr/bin/ruby
# coding: utf-8
require 'nokogiri'
require 'open-uri'
require 'mysql'

class SerpScrapper
  
  def initialize(phrase, searchEngUrl = 'http://www.google.com/search?q=', addParams = '&num=50')
    @phrase, @searchEngUrl, @addParams = phrase, searchEngUrl, addParams
  end
  
  def concat 
    @searchEngUrl + @phrase + @addParams
  end
  
  def open_file file_name
    serp = Nokogiri::HTML(open(file_name))
    puts serp
  end
    
  def save (file_name)
    serp = Nokogiri::HTML(open(self.concat))
    file = File.new(file_name, "w")
    file.puts serp
    file.close
  end
    
  def write2 #by regex, UTF problems
    open(self.concat) { |html| i=0
      # <h3 class="r"><a href="/url?q=http://www.piracki.pl/polsat&amp;...>PIRACKI POLSAT</a></h3>
      # (.+?)< - means look for the last <, 
      html.read.scan(/<h3 class="r"><a href="\/url\?q=(.+?)&amp;.+?>(.+?)<\/a><\/h3>/) { |link|
        puts (i+=1).to_s + ": #{link}\n"
      }
    }     
  end
    
  def execute #by Nokogiri, no problem with UTF, 
    i=0
    begin
      file_log = File.new("skaner.log", "w")
       
      # serp = Nokogiri::HTML(open(self.concat))
#       puts "Nokogiri: ", serp.encoding
      Nokogiri::HTML(open(self.concat)).css('h3.r').each { |h3|
        #[0] cause its the first element. could be more than one <a>
        #[1] cause match[0] (or url[0]) returns whole matched text, 1 is the first group (). 
        # <h3 class="r"><a href="/url?q=http://www.piracki.pl/polsat&amp;...>PIRACKI POLSAT</a></h3>
        # (.+?)< - means look for the last <, 
        # url = h3.css('a')[0]['href'].match(/\/url\?q(.+)&sa/)
        url = h3.css('a')[0]['href'].match(/\/url\?q=(.+\/\/(.+?)\/.*)&sa/)
        i+=1
        if url 
          # sometimes there is no url in h3, I found somethint like news search link added by G.
          #5 domain = url[1].match(/^.+\/\/(.+?)\//)[1] # [1] after match, cause its a group
          # puts "#{i} \n #{url[1]} \n #{url[2]} \n #{h3.content}"
          yield :position => i, :url => URI::decode(url[1]), :domain => url[2], :title => h3.content 
        else
          file_log.print url ? "Bad title: ": 'No "url?q=": '
          file_log.puts "#{h3}"
        end
      }
    ensure
      file_log.close
    end
      
    
  end #execute
  
  def parse_phrases
    
  end
   
  
  def to_s
    self.concat
  end  
end

def bad_title
  File.foreach('title.txt') { |line|  
    puts line.encoding
    puts line.valid_encoding?
    new_line = line.force_encoding("ISO-8859-1").encode("utf-8", replace: nil)
    puts new_line.valid_encoding?
    new_line.each_byte {|b| puts "#{b.to_s(16)}: #{b.chr}"}
    puts URI::unescape(new_line)
  } 
end

if false
  s = SerpScrapper.new(URI::encode('polsat film live'))
  s.open('22.txt')
end

# some aside tests
if false
  s = SerpScrapper.new(URI::encode('oglądaj polsat online'))  #'%C5%9Bwiat+wed%C5%82ug+kiepskich'
  s.execute { |p|
    # puts "#{p['position']}: #{p['domain']}"
    puts "#{p[:position]}: #{p[:domain]}" if p[:domain].match(/.*strato.*/)    
  }
  exit
end # some aside tests


begin
  con = Mysql.init 
  con.options(Mysql::SET_CHARSET_NAME, 'utf8')  # bez takich dwóch zaklęć nie będzie UTF-8!
  con.real_connect 'localhost', 'root', '', 'skaner' 
  if true
    con.query("SET FOREIGN_KEY_CHECKS=0;")
    con.query("TRUNCATE positions;")
    con.query("TRUNCATE urls;")
    con.query("TRUNCATE domains;")
    con.query("SET FOREIGN_KEY_CHECKS=1;")
  end

  rs_phrases = con.query 'SELECT * FROM phrases'
  rs_phrases.each_hash {|phrase|
    # next if phrase['id'].to_i < 22
    puts "**************************** #{phrase['id']}: #{phrase['name']}"
    s = SerpScrapper.new(URI::encode(phrase['name']))  #'%C5%9Bwiat+wed%C5%82ug+kiepskich'
    s.execute { |p|
      rs = con.query("SELECT id FROM domains where name='#{p[:domain]}'")
      if rs.num_rows == 0
        rs = con.query("INSERT INTO domains(name) VALUES('#{p[:domain]}')")
        domain_id = con.insert_id
      else
        domain_id = rs.fetch_row[0]
      end
  
      rs = con.query("SELECT id FROM urls where url='#{p[:url]}'")
      if rs.num_rows == 0
        rs = con.prepare "INSERT INTO urls (url, title, domain_id) VALUES(?, ?, ?)"
        puts p[:title], p[:title].encoding, p[:url], p[:domain]
        # there is problem with pages not encoded as UTF8, e.g. 8859-2
        # URI::unescape raises exception for some of these titles
        # so I found solution  force_encoding ets
        # URI::unescape is mandatroy too, cause it was impossible to save to mysql 
        # some titles with strange characters like \x93
        title = p[:title].valid_encoding? ? p[:title] : p[:title].force_encoding("ISO-8859-1").encode("utf-8", replace: nil)
        File.open("title.txt", "w") { |f| f.puts p[:title] }
        
        rs.execute p[:url], URI::unescape(title), domain_id
        url_id = con.insert_id
      else
        url_id = rs.fetch_row[0]
      end
      # puts "url_id: #{url_id}"
  
      rs = con.query "REPLACE INTO positions(position, phrase_id, url_id) VALUES(#{p[:position]}, #{phrase['id']}, #{url_id})"  
    }
  }
rescue Mysql::Error => e
    puts e.errno
    puts e.error
    
ensure
    con.close if con
end