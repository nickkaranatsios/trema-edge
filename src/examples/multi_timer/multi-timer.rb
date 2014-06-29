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
require 'ifconfig'
require 'pp'

class MultiTimer < Controller
  COLLECT_STATS_INTERVAL = 5.freeze
  TOPO_INTERVAL = 10.freeze

  oneshot_timer_event :store_topology, 10
  periodic_timer_event :check_timer, 1

  def start
    @redis_client = Redis.new
    @collect_stats_timer = { :callback => :collect_stats, :call_every => 10 }
    @topo_update_timer = { :callback => :topo_update, :call_once => 5 }
  end

  def collect_stats
    puts "collect stats called"
  end

  def topo_update
    puts "topo_update called"
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
    pp message
  end

  def table_multipart_reply datapath_id, message
    puts "table multipart reply from #{ datapath_id.to_s( 16 ) }"
    if message.parts.length > 0
      pp message.parts[ 0 ]
    end
  end


  def store_topology
    puts "update topology called"
  end

  #
  # process a packet in event from trema switch (datapath_id)
  #
  def packet_in datapath_id, message
    puts "packet in #{ datapath_id.to_s( 16 ) } in_port #{ message.match.in_port }"
    # pp message
  end
  

  #
  # periodically collect stats from all configured paths 
  # and update the redis db for the web application to read
  #
  def check_timer
    timers = instance_variables.grep(/_timer/)
    timers.each do | timer_var |
      eval <<-end_eval
        timer = instance_variable_get( timer_var )
        if timer[ :cur_count ]
          timer[ :cur_count ] = timer[ :cur_count ] + 1
        else
          timer[ :cur_count ] = 1
        end
        if timer[ :call_every ]
          if timer[ :cur_count ] >= timer[ :call_every ]
            timer[ :cur_count ] = 0
            send timer[ :callback ]
          end
        end
        if timer[ :call_once ]
          if !timer[ :expired ]
            if timer[ :cur_count ] >= timer[ :call_once ]
              timer[ :expired ] = true
              send timer[ :callback ]
            end
          end
        end
      end_eval
    end
  end

  ##############################################################################
  private
  ##############################################################################

end


### Local variables:
### mode: Ruby
### coding: utf-8
### indent-tabs-mode: nil
### End
