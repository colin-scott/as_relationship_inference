#!/usr/bin/ruby

File.foreach ARGV.shift do |line|
  system "wget http://data.caida.org/datasets/as-relationships/serial-1/#{line.chomp}"
  system "bunzip2 #{line.chomp}"
end
