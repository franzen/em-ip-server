require 'rubygems'
require 'eventmachine'
require_relative './thin_http_parser.rb'
 
# Freeze some HTTP header names & values
KEEPALIVE = "Connection: Keep-Alive\r\n".freeze
 
class RequestHandler < EM::Connection
  def post_init
    @parser = RequestParser.new
  end
 
  def receive_data(data)
    handle_http_request if @parser.parse(data)
  end
 
  def handle_http_request
    # p [@parser.env, @parser.body.string]
    keep_alive = @parser.persistent?

    ip = @parser.env['HTTP_X_FORWARDED_FOR'] || "127.0.0.1" # X-Client-IP, HTTP_CLIENT_IP, X-Forwarded-For
 
    send_data("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: #{ip.bytesize}\r\n#{ keep_alive  ? KEEPALIVE.clone : nil}\r\n#{ip}")
     
    if keep_alive
      post_init
    else
      close_connection_after_writing
    end
  end
end
 
host,port = "0.0.0.0", 8083
puts "Starting server on #{host}:#{port}, #{EM::set_descriptor_table_size(32768)} sockets"
EM.run do
  EM.start_server host, port, RequestHandler
  if ARGV.size > 0
    forks = ARGV[0].to_i
    puts "... forking #{forks} times => #{2**forks} instances"
    forks.times { fork }
  end
end
