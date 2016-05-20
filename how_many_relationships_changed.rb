#!/usr/bin/ruby

require 'set'
require 'csv'

class Top1000Filter
  def initialize
    @top_1000 = Set.new
    begin
      File.foreach("top_1000.dat") do |line|
        @top_1000.add(line.chomp.to_i)
      end
    catch
      $stderr.puts "WARNING: No top 1000 ranking file found. Skipping ranking filters"
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

class Analyzer
  def initialize
    title_row = ["delta","p2p_dis","p2c_dis","p2p_changed","p2c_changed","flipped","new_p2p","new_p2c"]
    @nop_csv = CSV.open("stacked_bar_chart/files/nop.csv", "wb")
    @nop_csv << title_row
    @nop_txt = File.open("nop_filter.txt","w")
    @weak_csv = CSV.open("stacked_bar_chart/files/weak.csv", "wb")
    @weak_csv << title_row
    @weak_txt = File.open("weak_filter.txt","w")
    @strict_csv = CSV.open("stacked_bar_chart/files/strict.csv", "wb")
    @strict_csv << title_row
    @strict_txt = File.open("strict_filter.txt","w")

    @epoch = 0
    @all_disappeared_p2p = Set.new
    @all_disappeared_p2c = Set.new
    @all_new_p2p = Set.new
    @all_new_p2c = Set.new
  end

  def close
    @nop_csv.close
    @nop_txt.close
    @weak_csv.close
    @weak_txt.close
    @strict_csv.close
    @strict_txt.close
  end

  # Side effect: increments epoch counter
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
      output_file.puts "%-30s %8d %01f" % [dataset, dat.size, percent(denom,dat)]

      # File.open(filename, "w") do |f|
      #   dat.each { |i| f.puts i.join(",") }
      # end
    end

    def print_temporary_disappearances
        puts "Total disappeared p2p: #{@all_disappeared_p2p.size}"
        p2p_isect = @all_disappeared_p2p & @all_new_p2p
        puts "Total that came back: #{p2p_isect.size} (#{p2p_isect.size * 100.0 / @all_disappeared_p2p.size})"

        puts "Total disappeared p2c: #{@all_disappeared_p2c.size}"
        p2c_isect = @all_disappeared_p2c & @all_new_p2c
        puts "Total that came back: #{p2c_isect.size} (#{p2c_isect.size * 100.0 / @all_disappeared_p2c.size})"
    end

    def percent(denom, dat)
      (dat.size * 100.0 / denom)
    end

    [["nop_filter",@nop_csv,@nop_txt], ["weak_filter",@weak_csv,@weak_txt], ["strict_filter",@strict_csv,@strict_txt]].each do |dataset,csv,txt|
      method = top_1000.method(dataset)
      denom = total1.select { |i| method.call(i) }.size
      p2p_dis = disappeared(p2p1,p2p2,p2c2).select { |i| method.call(i) }
      @all_disappeared_p2p += p2p_dis
      p2c_dis = disappeared(p2c1,p2p2,p2c2).select { |i| method.call(i) }
      @all_disappeared_p2c += p2c_dis
      p2p_changed = p2pchanged(p2p1,p2c2).select { |i| method.call(i) }
      p2c_changed = p2cchanged(p2c1,p2p2).select { |i| method.call(i) }
      flipped = flipped(p2c1,p2c2).select { |i| method.call(i) }
      new_p2p = disappeared(p2p2,p2p1,p2c1).select { |i| method.call(i) }
      @all_new_p2p += new_p2p
      new_p2c = disappeared(p2c2,p2p1,p2c1).select { |i| method.call(i) }
      @all_new_p2c += new_p2c
      txt.puts "====== #{epoch1} <-> #{epoch2} ======"
      txt.puts "denominator: #{denom}"
      print_and_dump("p2p_disappeared", txt, p2p_dis, denom)
      print_and_dump("p2c_disappeared", txt, p2c_dis, denom)
      print_and_dump("p2p_changed", txt, p2p_changed, denom)
      print_and_dump("p2c_changed", txt, p2c_changed, denom)
      print_and_dump("flipped", txt, flipped, denom)
      print_and_dump("new_p2p", txt, new_p2p, denom)
      print_and_dump("new_p2c", txt, new_p2c, denom)

      # Epoch number,p2p_dis,p2c_dis,p2p_changed,p2c_changed,flipped,new_p2p,new_p2c
      row = [@epoch, percent(denom,p2p_dis), percent(denom,p2c_dis), percent(denom,p2p_changed),
             percent(denom,p2c_changed), percent(denom,flipped), percent(denom,new_p2p), percent(denom,new_p2c)]
      csv << row
    end

    @epoch += 1
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
analyzer = Analyzer.new

# Assumes sorted filenames
files = Dir.glob("*as-rel.txt")
raise AssertionError.new unless files.size >= 1
next_input_file = files.shift
$stderr.puts "ingesting #{next_input_file}"
previous_data_object = DataFile.new(next_input_file)

while files.size >= 1
  next_input_file = files.shift
  $stderr.puts "ingesting #{next_input_file}"
  new_data_object = DataFile.new(next_input_file)

  p2c1 = previous_data_object.p2c
  p2c2 = new_data_object.p2c
  p2p1 = previous_data_object.p2p
  p2p2 = new_data_object.p2p
  epoch1 = previous_data_object.filename
  epoch2 = new_data_object.filename
  analyzer.compare_epochs(p2c1, p2c2, p2p1, p2p2, epoch1, epoch2, top_1000)

  previous_data_object = new_data_object
end

analyzer.print_temporary_disappearances
analyzer.close
