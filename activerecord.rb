#!/usr/bin/ruby

  
require 'mysql2' # or 'pg' or 'sqlite3'
require File.dirname(__FILE__) + "/skaner_model.rb"

@search = Search.create()
# search.save #time: DateTime.now
p @search
@domain = Domain.find_or_create_by(name: 'www.onet.pl')
p @domain
@url = Url.create_with(domain_id: @domain.id, url: 'http://www.onet.pl/erase1', title: 'Tytuł....').
  find_or_create_by(url: 'http://www.onet.pl/erase')
p @url
# position = Position.create(position: 51,  search_id: search.id, phrase_id: 1, url_id: 1)
@position = Position.find_or_create_by(position: 51,  search_id: @search.id, phrase_id: 1, url_id: @url.id)
p @position
exit

Search.all.each do |search|
  search.positions.each do |position|
    puts "#{search.time}, #{position.position}, #{position.url.title}"
  end
end