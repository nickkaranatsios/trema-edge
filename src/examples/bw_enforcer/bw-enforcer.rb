#
# Experimental application
#
# Author: Nick Karanatsios <nickkaranatsios@gmail.com>
#
# Copyright (C) 2014 NEC Corporation
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#


require 'ostruct'
require 'redis'
require 'trema/exact-match'
require 'json'
require 'observer'
require_relative 'dial-algorithm'
require_relative 'data-delegator'

class BwEnforcer < Controller
  include Observable
  oneshot_timer_event :store_topology, 10
  periodic_timer_event :reroute_test, 60

  def start
    @redis_client = Redis.new
    @dial_algorithm = DialAlgorithm.new
    @data = DataDelegator.new
    add_observer @dial_algorithm
  end

  def switch_ready datapath_id
    puts "switch ready 0x#{datapath_id.to_s( 16 )}"
    action = SendOutPort.new( port_number: OFPP_CONTROLLER, max_len: OFPCML_NO_BUFFER )
    ins = ApplyAction.new( actions: [ action ] )
    send_flow_mod_add( datapath_id,
                       priority: OFP_LOW_PRIORITY,
                       buffer_id: OFP_NO_BUFFER,
                       flags: OFPFF_SEND_FLOW_REM,
                       instructions: [ ins ]
    )
    # retrieve ports for switch
    send_message datapath_id, PortDescMultipartRequest.new 
  end

  def port_desc_multipart_reply datapath_id, message
    @data.ports.setup datapath_id, message.parts[ 0 ].ports
    @data.ports.to_s
    # at the moment assume that there are 0 parts in message
puts "datapath_id #{ datapath_id.to_s( 16 ) } #{ message.parts[ 0 ].ports }"
    switch = get_switch( datapath_id )
    unless switch.nil?
      @data.links.setup datapath_id, Trema::Link, switch.name, message.parts[ 0 ].ports
    end
  end

  def json_str v
    str = "["
    str += v.map { |x| x.to_h.to_json }.join( ',' )
    str << "]"
  end

  def store_topology
    @data.hosts.setup Trema::Host
    @data.hosts.to_s
    @data.links.each do | k, v |
      puts "key is #{ k } value is #{ v.inspect }"
      @redis_client.hset "topo", k.to_s( 16 ), json_str( v )
    end
    puts
    changed
    notify_observers self, @data.links.all
    puts @data.links.all.inspect
    return
    svg_js=""
#<!DOCTYPE html>
#<html>
#<body>
#
#<svg width="400" height="110">
#  <rect width="20" height="20" style="fill:rgb(0,0,255);stroke-width:3;stroke:rgb(0,0,0)"/>
# <line x1="20" y1="10" x2="50" y2="10" style="stroke:rgb(255,0,0);stroke-width:2" />
#  Sorry, your browser does not support inline SVG.  
#</svg>
# 
#</body>
#</html>
    svg_js += <<-EOT
      <!DOCTYPE html>
      <html>
      <body>
      <svg width="100%" height="100%">
    EOT
    @switches.each do | key, value |
      svg_js += <<-EOT
        <rect width="50" height="50", x="100", y="200"/>
      EOT
      puts  "0x#{ key.to_s(16) }, ports #{ value.inspect }"
      svg_js += <<-EOT
      EOT
      svg_js += <<-EOT
        "0x#{ key.to_s(16) }, ports #{ value.inspect }"
      EOT
    end
    puts svg_js
  end

  def find_links switch_name, ports
    links = []
    Trema::Link.each do | link |
      peers = link.peers[ 0 ].split( ':' )
      src = peers[ 0 ]
      if src == switch_name 
        link_node = OpenStruct.new( 
          from: src,
          from_dpid_short: src.to_i( 16 ),
          from_port: link.name,
          from_port_no: ports.select { | p | p.name == link.name }.first.port_no,
          to: link.peers[ 1 ],
          to_dpid_short: link.peers[ 1 ].to_i( 16 ),
          to_port: link.name_peer,
          config_cost: link.cost,
          current_cost: link.cost,
          bwidth: link.bwidth
        )
        links << link_node
      end
    end
    links
  end

  def packet_in datapath_id, message
    puts "packet in #{datapath_id.to_s(16)}, #{message.inspect}"
    dst_host_name = @data.hosts.select( message.packet_info.eth_dst.to_s ).name
    dst = dst_for( dst_host_name )
    src = get_switch( datapath_id )
puts "src = #{ src.name } dst = #{ dst }"
    if src.name != dst
      path = @dial_algorithm.execute src.name, dst
      return if path.empty?
    else
      # handle the case where src and dst is the same.
      path = []
      path << src.name
    end
    @data.paths.setup "#{ @data.hosts.select( message.packet_info.eth_src.to_s ).name }:#{ dst_host_name }", path, message
    path.push dst_host_name
    puts path.inspect
    install_path path, message
  end

  def reroute_test
    @data.paths.for_each_path do | src_dst_key, value |
      items = src_dst_key.split( ':' )
      src_host_name = items[ 0 ]
      dst_host_name = items[ 1 ]
      path = value.path
      message = value.pkt_in_message
      path.push dst_host_name
      puts path.inspect
      #reroute_path path, message
      send_flow_stats path, message
    end
  end

  def update_flow_stats link
    link.prev_packet_count = link.packet_count
    link.prev_byte_count = link.byte_count
    link.packet_count = part.packet_count
    link.byte_count = part.byte_count
  end

  def update_link_cost link
    unless link.bwidth.nil?
      rate = ( link.byte_count - link.prev_byte_count ) / ( link.bwidth  * 10**6 ) * 100
      adjust_link_cost link, rate
    end
  end

  def adjust_link_rate link, rate
    rate_intervals 
    if rate != 0  
    end
  end

  def process_flow_reply datapath_id, message
    links = @data.links.select( datapath_id )
    transaction_id = message.transaction_id
    flow_multi_replies = message.parts
    flow_multi_replies.each do | part |
      link = links[ transaction_id ]
      update_flow_stats link
      puts "link info: #{ link.inspect }"
      update_link_cost link
    end
  end

  def flow_multipart_reply datapath_id, message
    links = @data.links.select( datapath_id )
    puts "flow multipart reply from #{ datapath_id.to_s( 16 ) }, #{ message.inspect }"
    puts
    if message.parts.length > 0
      transaction_id = message.transaction_id
      flow_multi_replies = message.parts
      flow_multi_replies.each do | part |
        puts "packet count #{ part.packet_count } byte count #{ part.byte_count }"
        link = links[ transaction_id ]
        link.prev_packet_count = link.packet_count
        link.prev_byte_count = link.byte_count
        link.packet_count = part.packet_count
        link.byte_count = part.byte_count
        puts "link info: #{ link.inspect }"
        unless link.bwidth.nil?
          rate = ( link.packet_count - link.prev_packet_count ) / ( link.bwidth  * 10**6 ) * 100
          # test 
          # increment cost of link
          if rate != 0
            link.current_cost = link.current_cost + 1
          end
          @data.paths.for_each_path do | src_dst_key, value |
            path = value.path
            if path.include? link.from
puts "about to reroute"
              reroute_path path, value.pkt_in_message
            end
         end
        end
      end
    end
  end

  ##############################################################################
  private
  ##############################################################################


  def to_svg
  end

  def get_switch datapath_id
    ds = "0x#{ datapath_id.to_s(16) }"
    Trema::TremaSwitch.instances.values.select { | sw | sw.dpid_short == ds }.first
  end
 
  def dst_for host
    @data.links.each do | k, v |
      links = v
      edge = links.select { | l | l.to == host }
      unless edge.empty?
        return edge.first.from
      end
    end
    ""
  end

  def flow_mod datapath_id, match, port_no, command = :add
    action = SendOutPort.new( port_number: port_no )
    ins = Instructions::ApplyAction.new( actions: [ action ] )
    if command == :add
      send_flow_mod_add(
        datapath_id,
        match: match,
        instructions: [ ins ]
      )
    elsif command == :del
puts "sending a flow mod delete #{ match } #{ match.inspect }"
      send_flow_mod_del(
        datapath_id,
        match: match,
        out_port: OFPP_ANY,
        out_group: OFPG_ANY,
        instructions: [ ins ]
      )
    end
  end


  def packet_out datapath_id, message, port_no
puts "packet out to #{datapath_id}, port #{port_no}"
    action = Actions::SendOutPort.new( port_number: port_no )
    send_packet_out(
      datapath_id,
      packet_in: message,
      actions: [ action ]
    )
  end

  def send_flow_stats path, message
    match = ExactMatch.from( message )    
    dst_host = path.pop
    path.each_index do | idx |
      from_sw = path[ idx ]
      if idx == path.length - 1
        fwd_to = dst_host
      else
        fwd_to = path[ idx + 1 ]
      end
      link = @data.links.select( from_sw.to_i( 16 ) )
      each_link link do | l |
        if l.from == from_sw && l.to == fwd_to
          transaction_id = link.index( l )
puts "transaction id #{ transaction_id }"
          send_message l.from_dpid_short, FlowMultipartRequest.new( 
            transaction_id: transaction_id,
            cookie: 0,
            out_port: OFPP_ANY,
            out_group: OFPG_ANY,
            match: match
          )
          reverse_match = match_reverse( match )
          reverse_match.in_port = l.from_port_no
          send_message l.from_dpid_short, FlowMultipartRequest.new( 
            transaction_id: transaction_id,
            cookie: 0,
            out_port: OFPP_ANY,
            out_group: OFPG_ANY,
            match: reverse_match
          )
          match.in_port = @data.ports.select( l.to_dpid_short ).find_by_name( l.to_port ).port_no if l.to_dpid_short > 0
        end
      end
    end
  end

  def each_link link, &block
    unless link.nil?
      unless link.empty?
        link.each do | l |
          block.call l
        end
      end
    end
  end

  def install_path path, message
    match = ExactMatch.from( message )
puts match.inspect
    dst_host = path.pop
    packet_out_port = nil
    path.each_index do | idx |
      from_sw = path[ idx ]
      if idx == path.length - 1
        fwd_to = dst_host
      else
        fwd_to = path[ idx + 1 ]
      end
      link = @data.links.select( from_sw.to_i( 16 ) )
      unless link.nil?
        unless link.empty?
          link.each do | l |
            if l.from == from_sw && l.to == fwd_to
              packet_out_port = l.from_port_no if idx == 0
puts "sending a flow mod-add to #{ l.from_dpid_short.to_s( 16 ) } output to port #{ l.from_port_no } when match in_port #{ match.in_port }"
              flow_mod l.from_dpid_short, match, l.from_port_no

              output_port = match.in_port

              reverse_match = match_reverse( match )
              reverse_match.in_port = l.from_port_no

puts "sending a flow mod-add to #{ l.from_dpid_short.to_s( 16 ) } output to port #{ output_port } when match in_port #{ reverse_match.in_port }"
              flow_mod l.from_dpid_short, reverse_match, output_port

              match.in_port = @data.ports.select( l.to_dpid_short ).find_by_name( l.to_port ).port_no if l.to_dpid_short > 0
              sleep 1
            end
          end
        end
      end
    end
    packet_out message.datapath_id, message, packet_out_port unless packet_out_port.nil?
  end

  def reroute_path path, message
    match = ExactMatch.from( message )
    dst_host = path.pop
    path.each_index do | idx |
      from_sw = path[ idx ]
      if idx == path.length - 1
        fwd_to = dst_host
      else
        fwd_to = path[ idx + 1 ]
      end
      link = @data.links.select( from_sw.to_i( 16 ) )
      unless link.nil?
        unless link.empty?
          link.each do | l |
            if l.from == from_sw && l.to == fwd_to
              flow_mod l.from_dpid_short, match, l.from_port_no, :del
puts "sending a flow mod-del to #{ l.from_dpid_short.to_s( 16 ) } output to port #{ l.from_port_no } when match in_port #{ match.in_port }"
              output_port = match.in_port
              reverse_match = match_reverse( match )
              reverse_match.in_port = l.from_port_no

puts "sending a flow mod-del to #{ l.from_dpid_short.to_s( 16 ) } output to port #{ output_port } when match in_port #{ reverse_match.in_port }"
              flow_mod l.from_dpid_short, reverse_match, output_port, :del
              match.in_port = @data.ports.select( l.to_dpid_short ).find_by_name( l.to_port ).port_no if l.to_dpid_short > 0
              sleep 1
            end
          end
        end
      end
    end
  end

  def match_reverse match
    reverse_match = match.clone
    temp = reverse_match.eth_src
    reverse_match.eth_src = reverse_match.eth_dst
    reverse_match.eth_dst = temp
            
    temp = reverse_match.ipv4_src
    reverse_match.ipv4_src = reverse_match.ipv4_dst
    reverse_match.ipv4_dst = temp

    temp = reverse_match.udp_src
    reverse_match.udp_src = reverse_match.udp_dst
    reverse_match.udp_dst = temp
    reverse_match
  end

#  def each_link_from_to from, to, &block
#    each_link from, to, &block
#  end

#  def each_link from, to
#    array.select { | l.from == from && l.to == to }
#  end
  
end


### Local variables:
### mode: Ruby
### coding: utf-8
### indent-tabs-mode: nil
### End
