require 'ostruct'
require 'pp'

module FairShare
  def compute hosts, edge_to_core_links
    total_demand = hosts.reduce( 0 ) { | memo, h | memo + h.demand }
    puts "total_demand #{ total_demand }"
    total_capacity = edge_to_core_links.reduce( 0 ) { | memo, h | memo + h.bwidth }
    demand_count = count_of_unsatisfied( hosts )
    capacity_count = edge_to_core_links.length
    puts "total_capacity #{ total_capacity }"
    puts "demand count #{ count_of_unsatisfied( hosts ) }"

    hosts_to_compute = deep_clone( hosts )
    no_of_links = edge_to_core_links.length
    puts "capacity count #{ no_of_links }"
    edge_to_core_links.each do | link |
      capacity = link.bwidth
      puts "capacity is #{ capacity }"
      fair_share hosts_to_compute, capacity
      pp hosts_to_compute
      add_accumulated_demand hosts_to_compute
    end
    hosts_to_compute.sort! do | a, b | 
      b.accumulated_assigned_demand <=> a.accumulated_assigned_demand
    end
    pp hosts_to_compute
    edge_to_core_links.each do | link |
      capacity = link.bwidth
      tmp = 0
      fraction = 0.1
      hosts_to_compute.each do | h |
        if ( tmp + h.accumulated_assigned_demand ) < ( capacity + fraction )
          if h.edge_to_core.nil?
            tmp += h.accumulated_assigned_demand
            h.assigned_demand = h.accumulated_assigned_demand
            h.edge_to_core = link 
          end
        end
      end
    end
    if flag_any_unassigned hosts_to_compute
      puts "Failed to find a fair solution for all hosts"
      puts "Suggest increment the link capacity bandwidth"
      return []
    end
    hosts_to_compute
  end


  private

  def flag_any_unassigned hosts
    hosts.any? { | h | h.assigned_demand == 0 && h.edge_to_core.nil? }
  end

  def fair_share hosts, capacity
    unused_bwidth = capacity
    begin
      c = count_of_unsatisfied( hosts )
      break if c == 0
      calc_demand = unused_bwidth / c.to_f
      unused_bwidth = 0
      hosts.each do | h |
        if h.demand != h.assigned_demand
          if h.demand - ( h.assigned_demand + calc_demand ) < 0
            tmp = h.demand - h.assigned_demand
            h.assigned_demand += tmp
            unused_bwidth += calc_demand - tmp
          else
            h.assigned_demand += calc_demand
          end
          #puts "unused_bwidth #{ unused_bwidth }, #{ h.inspect }"
        end
      end
    end while unused_bwidth > 0
    hosts
  end

  def count_of_unsatisfied  hosts
    hosts.count { | h | h.demand != h.assigned_demand }
  end


  def add_accumulated_demand result
    result.each do | h |
      h.accumulated_assigned_demand = h.accumulated_assigned_demand + h.assigned_demand
      if h.accumulated_assigned_demand > h.demand
        h.accumulated_assigned_demand = h.demand
      end
      h.assigned_demand = 0
    end
  end

  def deep_clone obj
    to_obj = obj.inject( [] ) do | res, o |
      if o.assigned_demand != 0
        o.demand = o.assigned_demand
        o.assigned_demand = 0
        o.accumulated_assigned_demand = 0
      end
      res << o.clone
      res
    end
  end
end


#hosts = (1..4).inject([]) do | res, element |
#  res << OpenStruct.new( id: "host#{ element }", demand: element * 2, assigned_demand: 0, accumulated_assigned_demand: 0 ) 
#  res
#end
#
#hosts[0].demand = 6.0
#hosts[1].demand = 2.6
#hosts[2].demand = 5.0
#hosts[3].demand = 5.0
#
#class FairShareTest
#  include FairShare
#  def execute hosts, links
#    compute hosts, links
#  end
#end
#fst = FairShareTest.new
# links = []
# links << OpenStruct.new( name: "c1", bwidth: 5 )
# links << OpenStruct.new( name: "c2", bwidth: 5 )
# links << OpenStruct.new( name: "c3", bwidth: 7 )
#results = fst.execute( hosts, links )
#pp results
#
