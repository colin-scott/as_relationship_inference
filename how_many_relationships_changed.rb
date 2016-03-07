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

def compare_epochs(p2c1, p2c2, p2p1, p2p2, epoch1, epoch2, top_1000)
  # Output seven categories:
  # p2p -> p2c & p2p -> c2p
  # p2p -> no longer present
  # p2c -> p2p
  # p2c -> no longer present
  # p2c -> c2p & c2p -> p2c
  # new p2p
  # new p2c

  total1 = p2p1 | p2c1
  total2 = p2p2 | p2c2

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

  def print_and_dump(dataset, output_file, dat, denom)
    output_file.puts "%-30s %8d %01f" % [dataset, dat.size, (dat.size * 100.0 / denom)]

    # File.open(filename, "w") do |f|
    #   dat.each { |i| f.puts i.join(",") }
    # end
  end

  ["nop_filter", "weak_filter", "strict_filter"].each do |dataset|
    method = top_1000.method(dataset)
    denom = total1.select { |i| method.call(i) }.size
    # TODO(cs): performance improvement, could just open these files once...,
    # close at the end.
    File.open(dataset + ".txt", "a") do |f|
      f.puts "====== #{epoch1} <-> #{epoch2} ======"
      f.puts "denominator: #{denom}"
      print_and_dump("p2p_disappeared", f,
                     disappeared(p2p1,p2p2,p2c2).select { |i| method.call(i) }, denom)
      print_and_dump("p2c_disappeared", f,
                     disappeared(p2c1,p2p2,p2c2).select { |i| method.call(i) }, denom)
      print_and_dump("p2p_changed", f,
                     p2pchanged(p2p1,p2c2).select { |i| method.call(i) }, denom)
      print_and_dump("p2c_changed", f,
                     p2cchanged(p2c1,p2p2).select { |i| method.call(i) }, denom)
      print_and_dump("flipped", f,
                     flipped(p2c1,p2c2).select { |i| method.call(i) }, denom)
      print_and_dump("new_p2p", f,
                     disappeared(p2p2,p2p1,p2c1).select { |i| method.call(i) }, denom)
      print_and_dump("new_p2c", f,
                     disappeared(p2c2,p2p1,p2c1).select { |i| method.call(i) }, denom)
    end
  end
end

class DataFile
  attr_accessor :filename, :p2p, :p2c

  def initialize(file)
    @filename = file
    @p2c = Set.new
    @p2p = Set.new

    File.foreach(file) do |line|
      next if line.start_with? "#"
      provider,customer,type = line.chomp.split("|").map { |i| i.to_i }
      if type == 0
        @p2p.add([provider,customer])
      else
        @p2c.add([provider,customer])
      end
    end
  end
end

top_1000 = Top1000Filter.new

# Assumes sorted filenames
files = Dir.glob("*as-rel.txt")
raise AssertionError.new unless files.size >= 1
next_input_file = files.shift
puts "ingesting #{next_input_file}"
previous_data_object = DataFile.new(next_input_file)

while files.size >= 1
  next_input_file = files.shift
  puts "ingesting #{next_input_file}"
  new_data_object = DataFile.new(next_input_file)

  p2c1 = previous_data_object.p2c
  p2c2 = new_data_object.p2c
  p2p1 = previous_data_object.p2p
  p2p2 = new_data_object.p2p
  epoch1 = previous_data_object.filename
  epoch2 = new_data_object.filename
  compare_epochs(p2c1, p2c2, p2p1, p2p2, epoch1, epoch2, top_1000)

  previous_data_object = new_data_object
end
