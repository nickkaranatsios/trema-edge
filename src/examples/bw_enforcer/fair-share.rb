require 'ostruct'

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
puts "h is #{ h.inspect }"
        if h.demand != h.assigned_demand
          if h.demand - ( h.assigned_demand + calc_demand ) < 0
            tmp = h.demand - h.assigned_demand
            h.assigned_demand += tmp
            unused_bwidth += calc_demand - tmp
          else
            h.assigned_demand += calc_demand
          end
          puts "unused_bwidth #{ unused_bwidth }, #{h.inspect}"
        end
      end
puts
    end while unused_bwidth > 0
  end

  def count_of_unsatisfied 
    @hosts.count { | h | h.demand != h.assigned_demand }
  end
end


hosts = (1..4).inject([]) do | res, element |
  res << OpenStruct.new( demand: element * 2, assigned_demand: 0 ) 
  res
end

fs = FairShare.new( hosts, 10 )
fs.execute

