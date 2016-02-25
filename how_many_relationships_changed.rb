#!/usr/bin/ruby

require 'set'

class Top1000Filter
  def initialize
    @top_1000 = Set.new
    File.foreach("top_1000.dat") do |line|
      @top_1000.add(line.chomp.to_i)
    end
  end

  def strict_filter(pair)
    @top_1000.include? pair[0] and @top_1000.include? pair[1]
  end

  def weak_filter(pair)
    @top_1000.include? pair[0] or @top_1000.include? pair[1]
  end

  def nop_filter(pair)
    true
  end
end

top_1000 = Top1000Filter.new

# Ordered list of pairs: [filename, Set of AS pairs]
filename_2_p2c = []
# N.B. p2p pairs are ordered: <lower AS number, higher AS number>
filename_2_p2p = []

while not ARGV.empty?
  input_file = ARGV.shift

  p2c = Set.new
  filename_2_p2c <<= [input_file, p2c]
  p2p = Set.new
  filename_2_p2p <<= [input_file, p2p]

  File.foreach(input_file) do |line|
    next if line.start_with? "#"
    provider,customer,type = line.chomp.split("|").map { |i| i.to_i }
    if type == 0
      p2p.add([provider,customer])
    else
      p2c.add([provider,customer])
    end
  end
end

# Output seven categories:
# p2p -> p2c & p2p -> c2p
# p2p -> no longer present
# p2c -> p2p
# p2c -> no longer present
# p2c -> c2p & c2p -> p2c
# new p2p
# new p2c

# TODO(cs): generalize to >2
p2c1 = filename_2_p2c[0][1]
p2c2 = filename_2_p2c[1][1]
p2p1 = filename_2_p2p[0][1]
p2p2 = filename_2_p2p[1][1]

$total1 = p2p1 | p2c1
$total2 = p2p2 | p2c2

# init from epoch 0, p2p and p2c from epoch 1
def disappeared(init,p2p,p2c)
  init.select do |pair|
    not (p2c.include? pair or p2c.include? [pair[1],pair[0]] or p2p.include? pair.sort)
  end
end

def p2pchanged(p2p1,p2c2)
  p2p1.select do |pair|
    p2c2.include? pair or p2c2.include? pair.sort
  end
end

def p2cchanged(p2c1,p2p2)
  p2c1.select do |pair|
    p2p2.include? pair.sort
  end
end

def flipped(p2c1,p2c2)
  p2c1.select do |pair|
    p2c2.include? [pair[1],pair[0]]
  end
end

def print_and_dump(filename, dat, denom)
  File.open(filename, "w") do |f|
    puts "%-30s %8d %01f" % [filename, dat.size, (dat.size * 100.0 / denom)]
    dat.each { |i| f.puts i.join(",") }
  end
end

[[top_1000.method("nop_filter"),""],
 [top_1000.method("weak_filter"),".1edge"],
 [top_1000.method("strict_filter"),".2edge"]].each do |f,postfix|

  denom = $total1.select { |i| f.call(i) }.size
  puts "denominator: #{denom}"
  print_and_dump("p2p_disappeared.dat" + postfix,
                 disappeared(p2p1,p2p2,p2c2).select { |i| f.call(i) }, denom)
  print_and_dump("p2c_disappeared.dat" + postfix,
                 disappeared(p2c1,p2p2,p2c2).select { |i| f.call(i) }, denom)
  print_and_dump("p2p_changed.dat" + postfix,
                 p2pchanged(p2p1,p2c2).select { |i| f.call(i) }, denom)
  print_and_dump("p2c_changed.dat" + postfix,
                 p2cchanged(p2c1,p2p2).select { |i| f.call(i) }, denom)
  print_and_dump("flipped.dat" + postfix,
                 flipped(p2c1,p2c2).select { |i| f.call(i) }, denom)
  print_and_dump("new_p2p.dat" + postfix,
                 disappeared(p2p2,p2p1,p2c2).select { |i| f.call(i) }, denom)
  print_and_dump("new_p2c.dat" + postfix,
                 disappeared(p2c2,p2p1,p2c2).select { |i| f.call(i) }, denom)
  puts "============="
end
