require 'eventmachine'
require 'sinatra/base'
require 'thin'
require 'redis'


class DemoServlet < Sinatra::Base
  attr_reader :opf_controller
  attr_reader :redis_client

  def initialize controller
    @opf_controller = controller
    @redis_client = Redis.new
    super()
  end

  get '/' do
    @redis_client.get( "topology" )
    status = 200
#    response[ 'Content-Type' ] = 'application/json'
    response[ 'Content-Type' ] = 'text/plain'
    body = 'hello world'
  end
  
  get 'delayed-hello' do
    EM.defer do
      sleep 5
    end
    'background hello'
  end

  configure do
    set :threaded, false
  end
end
    
def run opts
  EM.run do
    server = opts[ :server ] || 'thin'
    host = opts[ :host ] || '0.0.0.0'
    port = opts[ :port ] || '4444'
    web_app = opts[ :app ]
    dispatch = Rack::Builder.app do
      map '/' do 
        run web_app
      end
    end
    Rack::Server.start({
      app: dispatch,
#      daemonize: true,
      server: server,
      Host: host,
      Port: port
    })
  end
end

run app: DemoServlet.new

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
