#!/usr/bin/ruby
# coding: utf-8
require 'nokogiri'
require 'open-uri'
require 'mysql2'
require 'active_record'
require 'logger'
require File.dirname(__FILE__) + "/skaner_model.rb"

class SerpScrapper
  
  def initialize(phrase, params = {})
    @phrase = phrase
    @searchEngUrl = params[:searchEngurl].nil? ? 'http://www.google.com/search?q=' : params[:searchEngurl]
    @addParams = params[:addParams].nil? ? '&num=50' : params[:addParams]
    #params[:hates_pickles]    = true if options[:hates_pickles].nil?  # default value for a bool  
    #phrase, searchEngUrl = 'http://www.google.com/search?q=', addParams = '&num=50')
    # @phrase, @searchEngUrl, @addParams = phrase, searchEngUrl, addParams
  end
  
  def concat 
    @searchEngUrl + @phrase + @addParams
  end
  
  def execute 
    i=0
    begin
      file_log = Logger.new File.open(File.dirname(__FILE__) + '/skaner.log', 'a') #.new("skaner.log", "w")
      file_log.level = Logger::INFO
       
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
          # debug_log.info "#{i} \n #{url[1]} \n #{url[2]} \n #{h3.content}"

          # there is problem with pages not encoded as UTF8, e.g. 8859-2
          # URI::unescape raises exception for some of these titles
          # so I found solution:  force_encoding etc
          # URI::unescape is mandatroy too, cause it was impossible to save to mysql
          # some titles with strange characters like \x93
          title = h3.content.valid_encoding? ? h3.content : h3.content.force_encoding("ISO-8859-1").encode("utf-8", replace: nil)
          yield :position => i, :url => URI::decode(url[1]), :domain => url[2], :title => URI::unescape(title) 
        else
          file_log.info (url ? "Bad title: ": 'No "url?q=": ') + h3
          puts h3
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

def compare_searches(phrase_id, search_id1, search_id2)
  distance_total, count, missed, distance_max, i = 0, 0, 0, 0, 0
  positions1 = Position.where(phrase_id: phrase_id, search_id: search_id1)
  count = positions1.count
  positions1.each do |position1|
    if (position2 = Position.find_by(phrase_id: phrase_id, search_id: search_id2, url_id: position1.url_id))
      distance_total += (position1.position - position2.position).abs
      # puts "#{position1.position}, #{position2.position}"
    else
      missed += 1
      distance_total += count - position1.position + 1 # distance to the count+1 position
      # puts "#{position1.position}, missed"
    end  
    i+=1 
    distance_max += i
  end
  p distance_max
  # distance_total += missed * count  # correct total distance with missed positions
  return { count: count, missed: missed, distance_total: distance_total, distance_average: distance_total/count, 
    similiarity: (-distance_total.to_f/distance_max) + 1 }
end

# select count(*), phrase_id from positions where search_id = 22 group by phrase_id 
for phrase_id in 1..40
  # p phrase_id
  p compare_searches(phrase_id, 20, 22)
end
exit

debug_log = Logger.new($stdout)
debug_log.level = Logger::INFO
  
count = 0
ActiveRecord::Base.transaction do
  search = Search.create()
  Phrase.all.each do |phrase|
    # next if phrase['id'].to_i < 22
    debug_log.debug phrase.inspect
    s = SerpScrapper.new(URI::encode(phrase.name))  #'%C5%9Bwiat+wed%C5%82ug+kiepskich'
    s.execute do |p|   
      domain = Domain.find_or_create_by(name: p[:domain])
      debug_log.debug domain.inspect
      url = Url.create_with(domain_id: domain.id, url: p[:url], title: p[:title]).find_or_create_by(url: p[:url])
      debug_log.debug url.inspect
      position = Position.create(position: p[:position],  search_id: search.id, phrase_id: phrase.id, url_id: url.id) 
      debug_log.debug  position.inspect
      count +=1
    end # search positions enumerator
  end # phrase
end # transaction
puts "Records added: #{count}"