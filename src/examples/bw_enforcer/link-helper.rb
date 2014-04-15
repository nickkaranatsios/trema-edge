module LinkHelper
  def update_link_cost link
    adjust( link ) unless link.bwidth.nil?
  end

  def update_flow_stats link, msg
    link.prev_packet_count = link.packet_count
    link.prev_byte_count = link.byte_count
    link.packet_count = msg.packet_count
    link.byte_count = msg.byte_count
  end

  def reroute_link link, paths
    paths.for_each_path do | src_dst_key, value |
      path = value.path
      if path.include? link.from
        puts "about to reroute #{ link.inspect }"
        #reroute_path path, value.pkt_in_message
      end
    end
  end

  private

  def adjust link
    if link.byte_count - link.prev_byte_count == 0 && link.byte_count != 0
      rate = ( link.byte_count * 8 ) * 100 / ( 60 * link.bwidth * 10**6 )
      puts "rate decreased by #{ rate }"
      decrease link
    else
      rate = ( link.byte_count - link.prev_byte_count ) * 8 * 100 / ( 60 * link.bwidth * 10**6 )
      puts "rate increased by #{ rate }"
      increase link
    end
  end

  def decrease link
    if link.current_cost - 1 >= link.config_cost
      link.current_cost = link.current_cost - 1
    end
  end

  def increase link
    if link.current_cost + 1 < link.config_cost * 10
      link.current_cost = link.current_cost + 1
    end
  end
end

