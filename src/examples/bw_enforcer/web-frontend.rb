require 'webrick'
require 'webrick/https'
require 'openssl'
include WEBrick

class DemoServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response.status = 200
    response[ 'Content-Type' ] = 'text/plain'
    response.body = 'hello world'
  end
end
    

server = WEBrick::HTTPServer.new( :Port => 1234 )
server.mount '/', DemoServlet

trap( 'INT' ) { server.shutdown }
server.start

authenticate = Proc.new do | req, res |
  HTTPAuth.basic_auth( req, res, "" ) do | usr, pwd |
    usr = 'demo' && pwd = 'demo123'
  end
end

s = HTTPServer.new(
  :Port => 8090,
  :ServerType => Daemon,
  :SSLEnable => true,
  :SSLVerifyClient => ::OpenSSL::SSL::VERIFY_NONE,
  :SSLCertName => [ %w(C JP), %w(O demossl.co), %w(CN WWW) ] 
)

