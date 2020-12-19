#!/usr/bin/env ruby

require 'net/https'
require 'fileutils'
require 'pp'
require 'json'

def ratingForIndex(idx)
	return 5 if idx > 75
	return 4 if idx > 60
	return 3 if idx > 40
	return 2 if idx > 20
	return 1
end

today = Time.new().to_s.split(" ").first

csv = Net::HTTP.get(URI('https://share.uzis.cz/s/BRfppYFpNTddAy4/download?path=%2F&files=pes_CR.csv')).force_encoding('UTF-8')
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

csv = Net::HTTP.get(URI('https://share.uzis.cz/s/BRfppYFpNTddAy4/download?path=%2F&files=pes_kraje.csv')).force_encoding('UTF-8')
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

	shire = { :id => shire_id, :name => shire_name, :index => idx, :r_value => er, :areas => { } }
	output[shire_id] = shire
}

csv = Net::HTTP.get(URI('https://share.uzis.cz/s/BRfppYFpNTddAy4/download?path=%2F&files=pes_okresy.csv')).force_encoding('UTF-8')
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
	shire[:areas][area_id] = { :id => area_id, :name => area_name, :index => idx, :r_value => er }
}

throw 'Data probably changed' if output.count < 5

output = { :date => today, :index => overall_idx, :r_value => overall_er, :data => output }

# puts JSON.pretty_generate(output)
filename = 'pes.json'
FileUtils.rm filename if File.exists? filename
File.open(filename, 'w'){|f| f << output.to_json }
