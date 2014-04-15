
# should be an observer to topology changes.
class DialAlgorithm
  attr_reader :topology

  def update controller, topology
    @topology = topology
  end

  def execute src = "e1", dst = "e2"
    dpids = @topology.keys
    origin = dpids.select { | k | k == src.to_i( 16 ) }
    # loop only if we origin is valid.
    path = []
    unless origin.empty?
      origin = origin.first
      # note "e1".to_i(16)
      links = @topology
      link_cost = assign_link_cost dpids, src.to_i( 16 )
      dl = {}
      pred = {}
      cost = 0
      dl[ cost ] = origin
      begin
        #puts "cost is #{ cost }"
        traverse links[ dl[ cost ] ], link_cost, dl, pred
        #puts dl.inspect
        #puts pred.inspect
        #puts link_cost.inspect
        dl.delete cost
      end while not ( cost = find_min( dl ) ).nil?
      #puts dl.inspect
      #puts "pred is #{ pred.inspect }"
      path = dial_path( pred )
    end
    path
  end

  private

  def assign_link_cost dpids, src
    link_cost = {}
    dpids.each do | dpid |
      hex_dpid = dpid.to_s( 16 )
      if dpid == src
        link_cost[ hex_dpid ] = 0
      else
        link_cost[ hex_dpid ] = 2** 32 - 1
      end
    end
    link_cost
  end

  def traverse links, link_costs, dl, pred
    links.each do | link |
      next if link.config_cost == 0
      cost = link_costs[ link.from ]
      new_cost = cost + link.current_cost
      if link_costs[ link.to ] > new_cost
        #puts "new cost #{ new_cost } for #{ link.to }"
        link.current_cost = new_cost
        pred[ link.to ] = link.from
        dl[ new_cost ] = link.to.to_i( 16 )
        link_costs[ link.to ] = new_cost
      end
    end
  end

  def find_min distance_labels
    keys = distance_labels.keys.sort
    cost = nil
    unless keys.empty?
      cost = keys.first
    end
    cost
  end

  def dial_path pred
    path = []
    pred.keys.reverse.each do | k |
      if path.empty? 
        path << k
        path << pred[ k ]
      else
        path << pred[ path.last ] unless pred[ path.last ].nil?
      end
    end
    puts "path = #{path.reverse.join("==>")}"
    path.reverse
  end
end
