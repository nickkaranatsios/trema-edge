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
require_relative 'fdb'
require_relative 'dial-algorithm'
require_relative 'data-delegator'

class BwEnforcer < Controller
  include Observable
  oneshot_timer_event :store_topology, 10

  def start
    @fdb = FDB.new
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
      switches[ datapath_id ] ||= find_links( switch.name, message.parts[ 0 ].ports )
    end
    # find the links for the current switch
  end

  def json_str v
    str = "["
    str += v.map { |x| x.to_h.to_json }.join( ',' )
    str << "]"
  end

  def store_topology
    @data.hosts.setup Trema::Host
    @data.hosts.to_s
    @switches.each do | k, v |
      puts "key is #{ k } value is #{ v.inspect }"
      @redis_client.hset "topo", k.to_s( 16 ), json_str( v )
    end
    changed
    notify_observers self, @switches
    @dial_algorithm.execute src = "e1", dst = "e2"
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
          cost: link.cost
        )
        links << link_node
      end
    end
    links
  end

  def packet_in datapath_id, message
    puts "packet in #{datapath_id}, #{message.inspect}"
    puts message.packet_info.eth_src
	  puts message.packet_info.ipv4
    puts message.packet_info.ipv4_src if message.packet_info.ipv4
    puts ( @data.hosts.select message.packet_info.eth_src.to_s ).inspect

    host_name = @data.hosts.select( message.packet_info.eth_dst.to_s ).name
    dest = dest_for( host_name )
    puts "dest is #{dest.inspect}"
    src = get_switch( datapath_id )
    puts src.name
    path = @dial_algorithm.execute src.name, dest
    path.push host_name
    puts path.inspect
    #if path empty send to flood packet
    install_path path, message
    packet_out datapath_id, message, 2
  end


  def age_fdb
#    @fdb.age
  end


  ##############################################################################
  private
  ##############################################################################

  def to_svg
  end

  def switches
    @switches ||= {}
  end

  def get_switch datapath_id
    ds = "0x#{ datapath_id.to_s(16) }"
    Trema::TremaSwitch.instances.values.select { | sw | sw.dpid_short == ds }.first
  end
 
  def dest_for host
    @switches.each do | k, v |
      links = v
      edge = links.select { | l | l.to == host }
      unless edge.empty?
        return edge.first.from
      end
    end
    ""
  end

  def flow_mod datapath_id, match, port_no
    action = SendOutPort.new( port_number: port_no )
    ins = Instructions::ApplyAction.new( actions: [ action ] )
    send_flow_mod_add(
      datapath_id,
      match: match,
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

  def install_path path, message
    match = ExactMatch.from( message )
puts match.inspect
    dst_host = path.pop
    path.each_index do | idx |
      from_sw = path[ idx ]
      if idx == path.length - 1
        fwd_to = dst_host
      else
        fwd_to = path[ idx + 1 ]
      end
      link = @switches[ from_sw.to_i( 16 ) ]
      unless link.empty? and link.nil?
        link.each do | l |
          if l.from == from_sw && l.to == fwd_to
puts "sending a flow mod to #{ l.from_dpid_short.to_s( 16 ) } to port #{ l.from_port_no } match in_port #{ match.in_port }"
            flow_mod l.from_dpid_short, match, l.from_port_no
            sleep 1
            match.in_port = @data.ports.select( l.to_dpid_short ).find_by_name( l.to_port ).port_no if l.to_dpid_short > 0
          end
        end
      end
    end
  end

  def flood datapath_id, message
    packet_out datapath_id, message, OFPP_ALL
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
