require 'ostruct'
require 'pp'

class FairShare
  def initialize hosts, link_capacity
    @hosts, @link_capacity = hosts, link_capacity
  end

  def execute
    fair_share
  end

  def fair_share 
    unused_bwidth = @link_capacity
    begin
      c = count_of_unsatisfied
      break if c == 0
      calc_demand = unused_bwidth / c.to_f
      unused_bwidth = 0
      @hosts.each do | h |
        if h.demand != h.assigned_demand
          if h.demand - ( h.assigned_demand + calc_demand ) < 0
            tmp = h.demand - h.assigned_demand
            h.assigned_demand += tmp
            unused_bwidth += calc_demand - tmp
          else
            h.assigned_demand += calc_demand
          end
          puts "unused_bwidth #{ unused_bwidth }, #{ h.inspect }"
        end
      end
    end while unused_bwidth > 0
  end

  def count_of_unsatisfied 
    @hosts.count { | h | h.demand != h.assigned_demand }
  end

  def to_s
    pp @hosts
  end
end


hosts = (1..5).inject([]) do | res, element |
  res << OpenStruct.new( demand: element * 2, assigned_demand: 0 ) 
  res
end

hosts[0].demand = 2.0
hosts[1].demand = 4.0
hosts[2].demand = 2.0
hosts[3].demand = 6.0
hosts[4].demand = 3.0

fs = FairShare.new( hosts, 15 )
fs.execute
fs.to_s

