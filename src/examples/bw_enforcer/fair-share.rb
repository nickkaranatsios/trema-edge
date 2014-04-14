require 'ostruct'

class FairShare
  def initialize hosts, link_capacity
    @hosts, @link_capacity = hosts, link_capacity
  end

  def execute
    link_capacity_per_flow = link_capacity / hosts.size
    total_residual = 0
    assigned_count = 0
    fair_share link_capacity_per_flow, residual, assigned_count
  end

  def fair_share link_capacity_per_flow, residual, assigned_count
    @hosts.each do | h |
      if link_capacity_per_flow > h.demand
        residual += link_capacity_per_flow - h.demand
        h.assigned_demand = link_capacity_per_flow
      end
      if h.unsatified_demand == 0
        h.unsatisfied_demand = h.demand - link_capacity_per_flow
        h.assigned_demand = link_capacity_per_flow
        assigned_count += 1
      else
        h.demand = h.unsatisfied_demand + residual
      end
      h.demand = h.assigned_demand
    end
    if residual > 0 
      link_capacity_per_flow = residual / assigned_count
      fair_share link_capacity_per_flow, residual, 0
    end
  end
end

hosts = (1..4).inject([]) do | res, element |
  res << OpenStruct.new( demand: element * 2, assigned_demand: 0, unsatisfied_demand: 0 ) 
  res
end

fs = FairShare.new( hosts, 10 )
fs.execute

