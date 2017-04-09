#!/usr/bin/env ruby
# encoding: UTF-8
require 'rubygems' # for ruby 1.8
require 'sinatra'
require 'json'
require 'net/http'
require 'dbi'
require './token'

$dbh = nil

def fetchRowFromDB(text)
  sth = $dbh.prepare("SELECT points FROM `we-play-board-games` WHERE thing = ?;")
  sth.execute(text)
  return sth.fetch() 
end

def fetchKarmaFromDB(text)
  row = fetchRowFromDB(text)
  if(row.nil?)
    return 0
  else
    return row['points']
  end
end

def adjustKarmaInDB(text,amt)
  row = fetchRowFromDB(text)
  if(row.nil?)
     sth = $dbh.prepare( "INSERT INTO `we-play-board-games`(thing,points) VALUES (?, ?);" )
     sth.execute(text,amt)
  else
     sth = $dbh.prepare("UPDATE `we-play-board-games` SET points = ? WHERE thing = ?;")
     newpoints = row['points'] + amt
     sth.execute(newpoints,text)
  end
end

def sendMessage(text, channel)
    uri = URI('https://slack.com/api/chat.postMessage')
    params = { :token => $token, :channel => channel, :text => text }
    uri.query = URI.encode_www_form(params)

    https = Net::HTTP.new(uri.host,uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.path+'?'+uri.query)
    res = https.request(req)
end

def handleChange(text,channel)
  regexp = /(\w+)(\+\+|--)/
  matches = text.scan(regexp)

  if(matches.length == 0)
    return
  end

  matches.each do |match|
    amt = (match[1]=='++' ? 1 : match[1]=='--' ? -1 : 0)
    adjustKarmaInDB(match[0],amt)
  end

end

def handleFetch(text,channel)
  if(!text.start_with?("!karma "))
    return
  end
  str = text[7...text.length]
  karma = fetchKarmaFromDB(str)
  sendMessage("#{str} has #{karma} karma",channel)
end


post '/message' do 
  req = JSON.parse(request.body.read)

  if(req["event"]["subtype"] || req["token"] != "L1jzs0c6I2WHhu7jfHaBR83O") 
    return
  end

  $dbh = DBI.connect("DBI:Mysql:karma:localhost","arubinoff", $dbtoken)

  channel = req["event"]["channel"]
  text = req["event"]["text"]

  #testing - only use the test channel for now
  puts req
  handleChange(text,channel)
  handleFetch(text,channel)

  $dbh.disconnect()

end