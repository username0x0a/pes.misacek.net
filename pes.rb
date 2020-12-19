#!/usr/bin/env ruby

require 'net/https'
require 'fileutils'
require 'pp'
require 'json'

$ratings = {
	:green  => { :min =>  0, :max =>  20, :severity => 1 },
	:yellow => { :min => 21, :max =>  40, :severity => 2 },
	:orange => { :min => 41, :max =>  60, :severity => 3 },
	:red    => { :min => 61, :max =>  75, :severity => 4 },
	:purple => { :min => 76, :max => 100, :severity => 5 },
}

def ratingForIndex(idx)
	$ratings.reverse_each {|k,v|
		return v[:severity] if idx >= v[:min]
	}
	return $ratings[:purple][:severity] if idx > 0
	return $ratings[:green][:severity]
end

today = Time.new().to_s.split(" ").first
filesURI = 'https://share.uzis.cz/s/BRfppYFpNTddAy4/download?path=%2F&files='

csv = Net::HTTP.get(URI(filesURI + 'pes_CR.csv')).force_encoding('UTF-8')
csv = csv.split("\n").select {|l| l.index(today) != nil }

overall_idx = nil
overall_rat = nil
overall_er = nil

csv.each{|line|

	data = line.split ';'
	next if data.count != 15

	overall_idx = data[2].to_i
	overall_rat = ratingForIndex overall_idx
	overall_er = data[9].to_f
}

throw 'Overall data error' if overall_idx == nil || overall_er == nil

output = { }

csv = Net::HTTP.get(URI(filesURI + 'pes_kraje.csv')).force_encoding('UTF-8')
csv = csv.split("\n").select {|l| l.index(today) != nil }

throw 'Bad shires count' if csv.count != 14

csv.each{|line|

	data = line.split ';'
	next if data.count != 17

	shire_id = data[2]
	shire_name = data[3]
	idx = data[4].to_i
	rat = ratingForIndex idx
	er = data[11].to_f

	# puts "#{area_name}: #{idx} (#{er})"

	shire = { :id => shire_id, :name => shire_name, :index => idx, :r_value => er, :_rating => rat, :areas => { } }
	output[shire_id] = shire
}

csv = Net::HTTP.get(URI(filesURI + 'pes_okresy.csv')).force_encoding('UTF-8')
csv = csv.split("\n").select {|l| l.index(today) != nil }

exit(0) if csv.count < 10

csv.each{|line|

	data = line.split ';'
	next if data.count != 19

	day = data[1]
	shire_id = data[2]
	shire_name = data[3]
	area_id = data[4]
	area_name = data[5]
	idx = data[6].to_i
	rat = ratingForIndex idx
	er = data[13].to_f

	# puts "#{area_name}: #{idx} (#{er})"

	shire = output[shire_id]
	throw 'Shire not found' if shire == nil
	shire[:areas][area_id] = { :id => area_id, :name => area_name, :index => idx, :r_value => er, :_rating => rat }
}

throw 'Data format has probably changed' if output.count < 5

output = { :date => today, :index => overall_idx, :r_value => overall_er, :_rating => overall_rat, :_ratings => $ratings, :data => output }
json = output.to_json + "\n" # JSON.pretty_generate(output)
filename = 'pes.json'

exit(0) if File.exists?(filename) && json == File.read(filename)

FileUtils.rm filename if File.exists? filename
File.open(filename, 'w'){|f| f << json }
