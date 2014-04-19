require 'ostruct'
require 'pp'

module FairShare
  def compute hosts, edge_to_core_links
    results = []
    #edge_to_core_links.each do | link |
    #  hosts_to_compute = deep_clone( hosts )
    #  capacity = link.bwidth
    #  results << fair_share( hosts_to_compute, capacity )
    #end
    hosts_to_compute = deep_clone( hosts )
    edge_to_core_links.each do | link |
      capacity = link.bwidth
      fair_share( hosts_to_compute, capacity )
      add_accumulated_demand hosts_to_compute
    end
    hosts_to_compute.sort! do | a, b | 
      b.accumulated_assigned_demand <=> a.accumulated_assigned_demand
    end
    pp hosts_to_compute
    results.take( 1 ).each_with_index do | item, i |
      item.each do | h |
        h.edge_to_core = edge_to_core_links[ i ]
        if h.demand != h.assigned_demand
          new_host, idx = choose_best( results, h )
          unless new_host.nil?
            h.edge_to_core = edge_to_core_links[ idx ]
            h.assigned_demand = new_host.assigned_demand
          end
        end
      end
    end
    results[ 0 ]
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

  private

  def choose_best( results, h )
    results.each_with_index do | item, i |
      best_host = item.detect { | each | each.id == h.id && each.assigned_demand > h.assigned_demand }
      return best_host,i unless best_host.nil?
    end
    return nil, 0
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


hosts = (1..4).inject([]) do | res, element |
  res << OpenStruct.new( id: "host#{ element }", demand: element * 2, assigned_demand: 0, accumulated_assigned_demand: 0 ) 
  res
end

hosts[0].demand = 6.0
hosts[1].demand = 2.6
hosts[2].demand = 5.0
hosts[3].demand = 5.0

class FairShareTest
  include FairShare
  def execute hosts, links
    compute hosts, links
  end
end
fst = FairShareTest.new
 links = []
 links << OpenStruct.new( name: "c1", bwidth: 10 )
 links << OpenStruct.new( name: "c2", bwidth: 4 )
results = fst.execute( hosts, links )
pp results

