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
require 'ifconfig'
require 'pp'
require_relative 'dial-algorithm'
require_relative 'data-delegator'
require_relative 'link-helper'
require_relative 'fair-share'

class BwEnforcer < Controller
  include Observable
  include LinkHelper
  include FairShare

  oneshot_timer_event :store_topology, 10
  periodic_timer_event :collect_stats, 30

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
    puts "port desc multipart reply from datapath_id #{ datapath_id.to_s( 16 ) }"
    pp message.parts[ 0 ].ports
    switch = get_switch( datapath_id )
    @data.links.setup datapath_id, Trema::Link, switch.name, message.parts[ 0 ].ports if switch
  end


  def store_topology
    puts "update topology called"
    @data.hosts.setup Trema::Host
    @data.hosts.to_s
    @all_hosts = @data.hosts.all.values
    redis_update_topology
    changed
    notify_observers self, @data.links.all
    redis_update_hosts @all_hosts
  end

  #
  # process a packet in event from trema switch (datapath_id)
  #
  def packet_in datapath_id, message
    puts "packet in #{ datapath_id.to_s( 16 ) }"
    #pp message
    return packet_in_fair_share datapath_id, message
  end
  

  #
  # periodically collect stats from all configured paths 
  # and update the redis db for the web application to read
  #
  def collect_stats
    dst_hosts =[]
    @data.paths.for_each_path do | src_dst_key, value |
      items = src_dst_key.split( ':' )
      src_host_name = items[ 0 ]
      dst_host_name = items[ 1 ]
      dst_hosts << dst_host_name
      path = value.path
      message = value.pkt_in_message
      path.push dst_host_name
      send_flow_stats path, message
    end
    redis_update_topology dst_hosts.uniq
    redis_host_config_changes_poll
    redis_link_config_changes_poll
  end

  def flow_multipart_reply datapath_id, message
    if datapath_id == 225
      puts "flow multipart reply from #{ datapath_id.to_s( 16 ) }"
      pp message
    end
    if message.parts.length > 0
      process_flow_stats_reply datapath_id, message
    end
  end

  ##############################################################################
  private
  ##############################################################################

  def packet_in_fair_share datapath_id, message
    edge_link = @data.links.select( datapath_id )
    src_host_name = @data.hosts.select( message.packet_info.eth_src.to_s ).name
    # sometimes we get a packet in from core switch that caused because the flow mod
    # is not installed yet or for some error in the switch. TODO identify the real
    # cause of the problem
    #
    return if edge_link.none? { | l | l.to == src_host_name }
    edge_hosts = []
    edge_to_core_links = []
    edge_link.each do | link |
      to = link.to
      host = @all_hosts.select { | h | h.name == to }
      if host.empty?
        edge_to_core_links << link
      else
        host.first.assigned_demand = 0
        edge_hosts << host.first
      end
    end
    #pp edge_to_core_links
    #pp edge_hosts
    result = compute( edge_hosts, edge_to_core_links )
    return if result.empty?
    pp result

    src = get_switch( datapath_id )
    dst_host_name = @data.hosts.select( message.packet_info.eth_dst.to_s ).name
    dst = dst_for( dst_host_name )
    if src.name != dst
      host = result.select { | h | h.name == src_host_name }
      unless host.empty?
        core_switch = host.first.edge_to_core.to
        path = @dial_algorithm.execute core_switch, dst
        path.insert( 0, src.name )
        path.push dst_host_name
      end
    else
      path = []
      path << src.name
    end
    return if path.empty?
    @data.paths.setup "#{ src_host_name }:#{ dst_host_name }", path, message
    pp path
    install_path path, message
  end

  def redis_update_topology dst_hosts=[]
    cfg = IfconfigWrapper.new.parse
    @data.links.each do | k, v |
      pp v
      v.each do | each |
        arr_host = @all_hosts.select { | h | h.name == each.to  }
        if !arr_host.empty?
          host = arr_host.first
          is_dst_host = dst_hosts.any? { | d | d == host.name }
          next if is_dst_host
          update_host_stats cfg[ each.from_port ].rx[ 'bytes' ], cfg[ each.from_port ].tx[ 'bytes' ], each
        end
      end
      @redis_client.hset "topo", k.to_s( 16 ), json_str( v )
      v.each do | each | 
        each.packet_count = 0
        each.byte_count = 0
        each.rx_byte_count = 0
        each.tx_byte_count = 0
      end
    end
  end

  def redis_update_hosts hosts
    hosts.each do | h |
      @redis_client.hset "hosts", h.name, { :name => h.name, :bwidth => h.demand }.to_json
    end
  end

  def redis_host_config_changes_poll
    keys = @redis_client.hkeys( 'hosts' )
    keys.each do | k |
      v = @redis_client.hget( 'hosts', k )
      data = JSON::parse( v )
      update_host_demand data, @all_hosts
    end
    pp @all_hosts
  end

  def redis_link_config_changes_poll
    keys = @redis_client.hkeys( 'links' )
    keys.each do | k |
      v = @redis_client.hget( 'links', k )
      data = JSON::parse( v )
      from = data[ 'from' ]
      link = @data.links.select( from.to_i( 16 ) )
      to = data[ 'to' ]
      bwidth = data[ 'bwidth' ].to_f
      link.each do | l |
        l.bwidth = bwidth if l.from == from && l.to == to 
      end
    end
  end

  def update_host_demand data, hosts
    host = hosts.select { | h | h.name == data[ 'name' ] }.first
    host.demand = data[ 'bwidth' ].to_f if host
  end

  def json_str v
    str = "["
    str += v.map { | x | x.to_h.to_json }.join( ',' )
    str << "]"
  end

  def process_flow_stats_reply datapath_id, message
    links = @data.links.select( datapath_id )
    transaction_id = message.transaction_id
    rx = false
    if transaction_id >= links.length 
      rx = true
      link = links[ transaction_id - links.length ]
    else
      link = links[ transaction_id ]
    end
    flow_multi_replies = message.parts
    flow_multi_replies.each_with_index do | msg |
      update_flow_stats link, msg, rx
    end
  end

  def get_switch datapath_id
    ds = "0x#{ datapath_id.to_s(16) }"
    Trema::TremaSwitch.instances.values.select { | sw | sw.dpid_short == ds }.first
  end
 
  def dst_for host
    @data.links.each do | k, v |
      links = v
      edge = links.select { | l | l.to == host }
      return edge.first.from if !edge.empty?
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
          adjust_link_capacity l
          puts "fs tx transaction id #{ link.index( l ) } rx transaction id #{ link.index( l ) + link.length } from #{ l.from } to #{ l.to }"
          send_message l.from_dpid_short, FlowMultipartRequest.new( 
            transaction_id: link.index( l ),
            cookie: 0,
            out_port: OFPP_ANY,
            out_group: OFPG_ANY,
            match: match
          )
          reverse_match = match_reverse( match )
          reverse_match.in_port = l.from_port_no
          send_message l.from_dpid_short, FlowMultipartRequest.new( 
            transaction_id: link.index( l ) + link.length,
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
    if link
      if !link.empty?
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
      if link
        if !link.empty?
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
            end
          end
        end
      end
    end
    sleep 2
    packet_out message.datapath_id, message, packet_out_port if packet_out_port
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
      if link
        if !link.empty?
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
