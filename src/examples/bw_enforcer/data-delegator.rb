require 'delegate'
require 'ostruct'

class HostHash
  attr_reader :hosts

  def setup config_hosts
    config_hosts.each do | h |
      hosts[ h.mac ] = OpenStruct.new( name: h.name, mac: h.mac, ip: h.ip )
    end
  end

  def select key
    @last_host = @hosts[ key ]
  end

  def to_s
    puts "hosts: #{ @hosts.inspect }"
  end
  private

  def hosts
    @hosts ||= {}
  end
end


class PortHash
  attr_reader :ports

  def setup key, config_ports
    all_ports = config_ports.inject( [] ) do | res, p |
      res << OpenStruct.new( name: p.name, port_no: p.port_no )
      res
    end
    ports[ key ] = all_ports
  end

  def select key
    @last_port = @ports[ key ]
    self
  end

  def find_by_name name
    @last_port.select { | p | p.name == name }.first
  end

  def to_s
    puts "ports: #{ @ports.inspect }"
  end

  private 

  def ports
    @ports ||= {}
  end
end

class LinkHash
end

class PathHash
  attr_reader :paths

  def setup key, path, pkt_in_message
    # key is a concatenation of src and dst vhost's names
    # one distinct path from src to dst
    paths[ key ] = OpenStruct.new( path: path, pkt_in_message: pkt_in_message )
  end

  def for_each_path &block
    @paths.each do | k, v |
      block.call k, v
    end
  end

  def select_all
    @paths.values
  end

  def paths
    @paths ||= {}
  end
end


class DataDelegator < SimpleDelegator
  def initialize
    %w( Host Link Port Path ).each do | cls |
      method = "#{ cls.downcase }s"
      attr = "@#{ method }"
      eval "#{ attr } = #{ cls }Hash.new"
    end
#    @hosts = HostHash.new
#    @links = LinkHash.new
#    @ports = PortHash.new
    super @hosts
  end

  def links
    __setobj__ @links
  end

  def hosts
    __setobj__ @hosts
  end

  def ports
    __setobj__ @ports
  end

  def paths
    __setobj__ @paths
  end
end

#dd = DataDelegator.new
#class P
#  attr_accessor :name, :port_no
# def initialize name, number
#   @name = name
#   @port_no = number
# end
#end
#dd.ports.setup( 123, [ P.new( "p2", 2) ] )
#dd.ports.setup( 124, [ P.new( "p1", 1) ] )
#x = dd.ports.select(123).find_by_name("p2").port_no
#puts x
#
