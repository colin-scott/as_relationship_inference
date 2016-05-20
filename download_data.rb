#!/usr/bin/ruby

# ARGV[0] is a list of dates to be downloaded. Presumably taken from
# http://data.caida.org/datasets/as-relationships/serial-1/

File.foreach ARGV.shift do |line|
  system "wget http://data.caida.org/datasets/as-relationships/serial-1/#{line.chomp}"
  system "bunzip2 #{line.chomp}"
end
