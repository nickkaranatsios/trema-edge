require 'sinatra/base'
require 'redis'
require 'json'

class DemoServlet < Sinatra::Base
  attr_reader :redis_client

  def initialize
    @redis_client = Redis.new
    super()
  end

  get '/' do
    redirect '/index.html'
    keys = @redis_client.hkeys( "topo" )
    keys.each do | k |
      v = @redis_client.hget( "topo", k )
      ary_hash = JSON.parse( v )
      ary_hash.each do | h |
        puts h.inspect
      end
    end
    status = 200
#    response[ 'Content-Type' ] = 'application/json'
    response[ 'Content-Type' ] = 'text/plain'
    body = 'hello world'
  end

  get '/topology' do
    topology.to_json
  end

  put '/topology/*' do | key |
    h = topology
    h[ key ].to_json
  end
  
  configure( :delevelopment ) do | c |
    require "sinatra/reloader"
    c.also_reload "*.rb"
    set :public_folder, "./public"
  end

  private

  def topology( h={} )
    keys = @redis_client.hkeys( 'topo' )
    h[ 'topo-keys' ] = keys
    keys.each do | k |
      v = @redis_client.hget( 'topo', k )
      h[ k ] = v
    end
    h
  end
end
    
#run app: DemoServlet.new

#
#
#authenticate = Proc.new do | req, res |
#  HTTPAuth.basic_auth( req, res, "" ) do | usr, pwd |
#    usr = 'demo' && pwd = 'demo123'
#  end
#end
#
#s = HTTPServer.new(
#  :Port => 8090,
#  :ServerType => Daemon,
#  :SSLEnable => true,
#  :SSLVerifyClient => ::OpenSSL::SSL::VERIFY_NONE,
#  :SSLCertName => [ %w(C JP), %w(O demossl.co), %w(CN WWW) ] 
#)
#
