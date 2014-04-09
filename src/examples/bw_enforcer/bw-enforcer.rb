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
require_relative 'fdb'


class BwEnforcer < Controller
#  oneshot_timer_event :get_list_switches, 10
  oneshot_timer_event :store_topology, 10

  def start
puts "start is called"
    @fdb = FDB.new
    @redis_client = Redis.new
  end

  def switch_ready datapath_id
    puts "switch ready 0x#{datapath_id.to_s(16)}"
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

  def list_switches_reply dpids
    puts "list_switches reply #{dpids.inspect}"
    dpids.each do | dpid |
      port_desc_request = PortDescMultipartRequest.new( transaction_id: 123 )
      send_message dpid, port_desc_request
    end
  end

  def get_list_switches
puts "sending list switches"
puts "trema switches #{Trema::TremaSwitch.instances.inspect}"
    send_list_switches_request
  end

  def port_desc_multipart_reply datapath_id, message
    switch = get_switch( datapath_id )
    unless switch.empty?
      sw = switch.shift
      switches[ datapath_id ] ||= find_links( sw.name )
    end
    # find the links for the current switch
  end

  def json_str v
    str = "["
    str += v.map { |x| x.to_h.to_json }.join( ',' )
    str << "]"
  end

  def store_topology
    @switches.each do | k, v |
      puts "key is #{ k } value is #{ v.inspect }"
      @redis_client.hset "topo", k.to_s(16), json_str( v )
    end
    dial_algorithm
    return
    puts @switches.inspect
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

  def find_links switch_name
    links = []
    Trema::Link.each do | link |
      peers = link.peers[ 0 ].split( ':' )
      src = peers[ 0 ]
      if src == switch_name 
        link_node = OpenStruct.new
        link_node.from = src
        link_node.from_port = link.name
        link_node.to = link.peers[ 1 ]
        link_node.to_port = link.name_peer
        link_node.cost = link.cost
        links << link_node
      end
    end
    links
  end

  def packet_in datapath_id, message
puts "packet in #{datapath_id}, #{message.inspect}"
    @fdb.learn message.eth_src, message.in_port
    port_no = @fdb.port_no_of( message.eth_dst )
puts "port_no = #{ port_no }"
    if port_no
      flow_mod datapath_id, message, port_no
      packet_out datapath_id, message, port_no
    else
      flood datapath_id, message
    end
  end


  def age_fdb
#    @fdb.age
  end


  ##############################################################################
  private
  ##############################################################################

  def dial_algorithm
    # assign dl[ 0 ] = src
    # find_min_next_node dl
    # while find_min_next_node
    # end
    # start with edge switch 1
    distance_label = {}
    edge_sw = @switches.keys.select { | k | k == 225 }
    unless edge_sw.empty?
      # note "e1".to_i(16)
      topo = @switches
      dl = {}
      pred = {}
      edge = edge_sw.first
      links = topo[ edge ]
      cost = 0
      links.each do | link |
        next if link.cost == 0
        to_cost = 100
        dl[ cost ] = link.from
        new_cost = cost + link.cost
puts "new cost #{ new_cost }"
        if to_cost > new_cost
          link.cost = new_cost
          pred[ link.to ] = link.from
          dl[ new_cost ] = link.to
        end
      end
      puts dl.inspect
      puts pred.inspect
    end
  end


  def to_svg
  end

  def switches
    @switches ||= {}
  end

  def get_switch datapath_id
    ds = "0x#{ datapath_id.to_s(16) }"
    Trema::TremaSwitch.instances.values.select { | sw | sw.dpid_short == ds }
  end
 

  def flow_mod datapath_id, message, port_no
    action = SendOutPort.new( port_number: port_no )
    ins = Instructions::ApplyAction.new( actions: [ action ] )
    send_flow_mod_add(
      datapath_id,
      match: ExactMatch.from( message ),
      instructions: [ ins ]
    )
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


  def flood datapath_id, message
    packet_out datapath_id, message, OFPP_ALL
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8
### indent-tabs-mode: nil
### End
