module LinkHelper
  attr_reader :adjusted

  def entrance_cost path, links
    return if path.length < 3
    src = path[ 0 ]
    dst = path[ 1 ]
    link = links[ src.to_i( 16 ) ]
    unless link.nil?
      l = link.select { | e | e.from == src && e.to == dst }
puts "l is #{ l.inspect }"
      unless l.empty?
        o = l.pop
        o.cost = o.cost + 1
      end
    end
  end

  def update_link_cost link, msg
    @adjusted = false
    return if msg.byte_count == 0
    adjust link
  end

  def update_flow_stats link, msg
    link.packet_count += msg.packet_count
    link.byte_count += msg.byte_count
  end

  def update_host_stats stats, link
    return if stats.nil?
    unless stats.ip_src.nil?
      link.packet_count += stats.n_pkts 
      link.byte_count += stats.n_octets
    end
  end

  def adjust_link_capacity link
    if link.packet_count < link.prev_packet_count
      link.packet_count = link.prev_packet_count
    else
      link.prev_packet_count = link.packet_count
    end
    if link.byte_count < link.prev_byte_count
      link.byte_count = link.prev_byte_count
    else
      link.prev_byte_count = link.byte_count
    end
  end

  def reroute_link link, paths
    paths.for_each_path do | src_dst_key, value |
      path = value.path
      if path.include? link.from
        puts "about to reroute #{ link.inspect }"
        reroute_path path, value.pkt_in_message
      end
    end
  end

  def link_adjusted?
    @adjusted
  end

  private

  def adjust link
    if link.byte_count - link.prev_byte_count == 0
      rate = ( link.byte_count * 8 ) * 100 / ( 60 * link.bwidth * 10**6 )
      decrease link, rate
    else
      rate = ( link.byte_count - link.prev_byte_count ) * 8 * 100 / ( 60 * link.bwidth * 10**6 )
      # TODO classify link as to how congested is
      increase link, rate
    end
  end

  def decrease link, rate
    return if rate == 0 || link.byte_count == 0
    if link.cost - 1 >= link.config_cost
      #link.cost = link.cost - 1
      puts "rate decreased by #{ rate }"
      #@adjusted = true
    end
  end

  def increase link, rate
    if link.cost + 1 < link.config_cost * 10
      link.cost = link.cost + 1
      puts "rate increased by #{ rate }"
      @adjusted = true
    end
  end
end

