#!/usr/bin/ruby

# Ranking file (ARGV[0]) comes from CAIDA AS Ranking website.

# Format:
# 1	3356	LEVEL3	Level 3 Communications, Inc.	 Tr/Ac 	24,553	190,138	715,498,496	
# 47%
# 32%
# 33%
# 4260
# 2	174	COGENT-174	Cogent Communications	 Tr/Ac 	17,891	134,631	648,411,904	
# 34%
# 22%
# 30%
# 4813

File.foreach(ARGV.shift) do |line|
  split = line.chomp.split
  next if split.size < 2
  as = split[1]
  puts as
end
