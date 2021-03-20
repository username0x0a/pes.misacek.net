#!/usr/bin/env ruby

require 'net/https'
require 'json'
require 'fileutils'
require 'pp'

class String
	def getValue(*args)
		throw :too_few_arguments if args.size < 1
		patterns = args[0..-2]
		terminator = args[-1]
		start = 0
		end_ = 0
		patterns.each do|pattern|
			start = self.index(pattern, start)
			start += pattern.length
		end
		end_ = terminator == :eol || terminator == nil ?
			-1 : self.index(terminator, start) - 1
		return self[start..end_]
	end
end

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

today = Time.new.to_s.split(" ").first
filterToday = today.split('-').reverse.join('.')

data = Net::HTTP.get(URI('https://flo.uri.sh/visualisation/4366507/embed'))
data = data.getValue '_Flourish_data = ', ';'
json = JSON.parse data
data = json['data']
data = data.select {|e| e['label'] == filterToday }

throw 'Overall data error' if data.count != 15

regions = data.map {|e| e['filter'] }

ids = {
	"Celá ČR" => "CZ000",
	"Hl. m. Praha" => "CZ010",
	"Středočeský kraj" => "CZ020",
	"Jihočeský kraj" => "CZ031",
	"Plzeňský kraj" => "CZ032",
	"Karlovarský kraj" => "CZ041",
	"Ústecký kraj" => "CZ042",
	"Liberecký kraj" => "CZ051",
	"Královéhradecký kraj" => "CZ052",
	"Pardubický kraj" => "CZ053",
	"Kraj Vysočina" => "CZ063",
	"Jihomoravský kraj" => "CZ064",
	"Olomoucký kraj" => "CZ071",
	"Zlínský kraj" => "CZ072",
	"Moravskoslezský kraj" => "CZ080",
}

data = data.map {|e|
	id = ids[e['filter']]
	throw "Invalid region" if !id.is_a? String
	idx = e['value'][0].to_i
	region = {
		:id => id,
		:name => e['filter'],
		:index => idx,
		:r_value => e['value'][1].to_f,
		:_rating => ratingForIndex(idx),
		:areas => {},
	}
	region
}

countryData = data[0]
data.shift

data = data.reduce({}) { |obj, elm| obj[elm[:id]] = elm; obj }

output = {
	:date => today,
	:index => countryData[:index],
	:r_value => countryData[:r_value],
	:_rating => countryData[:_rating],
	:_ratings => $ratings,
	:data => data,
}

json = output.to_json + "\n" # JSON.pretty_generate(output)
filename = 'pes.json'

exit(0) if File.exists?(filename) && json == File.read(filename)

FileUtils.rm filename if File.exists? filename
File.open(filename, 'w'){|f| f << json }
