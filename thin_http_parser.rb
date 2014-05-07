require 'rubygems'
# Uncomment this line if 'thin_parser' is not found
# require 'thin'
require 'thin_parser'
require 'stringio'
 
# Freeze some HTTP header names & values
HTTP_VERSION      = 'HTTP_VERSION'.freeze
HTTP_1_0          = 'HTTP/1.0'.freeze
CONTENT_LENGTH    = 'CONTENT_LENGTH'.freeze
CONNECTION        = 'HTTP_CONNECTION'.freeze
KEEP_ALIVE_REGEXP = /\bkeep-alive\b/i.freeze
CLOSE_REGEXP      = /\bclose\b/i.freeze
 
# Freeze some Rack header names
RACK_INPUT        = 'rack.input'.freeze
 
# A request sent by the client to the server.
class RequestParser
  INITIAL_BODY      = ''
 
  # Force external_encoding of request's body to ASCII_8BIT
  INITIAL_BODY.encode!(Encoding::ASCII_8BIT) if INITIAL_BODY.respond_to?(:encode!)
 
  # CGI-like request environment variables
  attr_reader :env
 
  # Unparsed data of the request
  attr_reader :data
 
  # Request body
  attr_reader :body
 
  def initialize
    @parser   = Thin::HttpParser.new
    @data     = ''
    @nparsed  = 0
    @body     = StringIO.new(INITIAL_BODY.dup)
    @env      = {
      RACK_INPUT        => @body,
    }
  end
 
  # Parse a chunk of data into the request environment
  # Returns +true+ if the parsing is complete.
  def parse(data)
    if @parser.finished?  # Header finished, can only be some more body
      body << data
    else                  # Parse more header using the super parser
      @data << data
      @nparsed = @parser.execute(@env, @data, @nparsed)
    end
 
    if finished?   # Check if header and body are complete
      @data = nil
      @body.rewind
      true         # Request is fully parsed
    else
      false        # Not finished, need more data
    end
  end
 
  # +true+ if headers and body are finished parsing
  def finished?
    @parser.finished? && @body.size >= content_length
  end
 
  # Expected size of the body
  def content_length
    @env[CONTENT_LENGTH].to_i
  end
 
  # Returns +true+ if the client expect the connection to be persistent.
  def persistent?
    # Clients and servers SHOULD NOT assume that a persistent connection
    # is maintained for HTTP versions less than 1.1 unless it is explicitly
    # signaled. (http://www.w3.org/Protocols/rfc2616/rfc2616-sec8.html)
    if @env[HTTP_VERSION] == HTTP_1_0
      @env[CONNECTION] =~ KEEP_ALIVE_REGEXP
 
    # HTTP/1.1 client intends to maintain a persistent connection unless
    # a Connection header including the connection-token "close" was sent
    # in the request
    else
      @env[CONNECTION].nil? || @env[CONNECTION] !~ CLOSE_REGEXP
    end
  end
end
