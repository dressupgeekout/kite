#
# Kite
# Charlotte Koch <cfkoch@edgebsd.org>
#

require 'rack'

# A Route is a collection of Rack environment data and the actions to be taken
# when a HTTP request matches that environment.
class Route < Hash
  include Comparable

  # Routes are arranged such that the more specific routes are "greater than"
  # the less specific routes. Longer routes are more specific. Routes with a
  # greater number of strings are more specific than routes with a greater
  # number of regexen.
  def <=>(another)
    if self[:path_segments].length == another[:path_segments].length
      a_strings = self[:path_segments].select { |e| e.is_a?(String) }.length
      b_strings = another[:path_segments].select { |e| e.is_a?(String) }.length
      a_strings > b_strings ? 1 : -1
    else
      self[:path_segments].length > another[:path_segments].length ? 1 : -1
    end
  end
end

# A Kite application is a collection of routes which respond to Rack calls.
class Kite

  VERSION = '0.1.1'

  include Enumerable

  # Iterate through all of this application's routes, longest first.
  def each
    @routes.sort.reverse.each { |r| yield r }
  end

  attr_reader :req, :res

  # Create a new Kite app.
  def initialize(&block)
    @routes = []
    @default = Route[
      :block, Proc.new{ @res.status = 404; puts "404 NOT FOUND" }
    ]
    self.instance_eval(&block)
  end

  # The Rack heavy lifting. Most of the dirty work is delegated to #find_route! 
  def call(env)
    @req = Rack::Request.new(env)
    @res = Rack::Response.new

    catch(:halt) do
      split_path_info!
      route = find_route! || @default
      route[:block_params] = [route[:request_method], *@spi]
      route[:block].call(route[:block_params])
    end

    @res.finish
  end

  # Make Kite aware of a new route.
  def on(request_method, *path_segments, &block)
    @routes << Route[
      :request_method, request_method,
      :path_segments,  path_segments,
      :block_params,   [request_method, *path_segments],
      :block,          block
    ]
  end

  def get; 'GET'; end
  def post; 'POST'; end
  def put; 'PUT'; end
  def delete; 'DELETE'; end

  # The setter for the default response.
  def default(&block)
    @default[:block] = block
  end

  # Force the application to stop whatever it's doing and return the default
  # response.
  def default!
    @default[:block].call
    throw :halt
  end

  # Matches any sequence of digits.
  def number
    /\A(\d+)\z/
  end

  # Matches any sequence of "URL-safe" characters (alphanumeric, hyphen, and
  # underscore).
  def segment
    /\A([\w-]+)\z/
  end

  # A wrapper around Rack::Response#write.
  def print(*strings)
    strings.each { |s| @res.write s }
  end

  # A wrapper around Rack::Response#write.
  def puts(*strings)
    strings.each { |s| @res.write "#{s}\n" }
  end

  private

  # Split the requested URL into segments.
  def split_path_info!
    if (@req.path_info == '/')
      @spi = ['/']
    else
      @spi = @req.path_info.sub('/', '').split('/')
    end
  end

  # Given a request, determine which route's action should be called.
  def find_route!
    self.detect do |route|
      next if route[:request_method] != @req.request_method
      next if route[:path_segments].length != @spi.length
      (0...(route[:path_segments].length)).collect { |i|
        @spi[i].match(route[:path_segments][i]).to_a.first
      }.all?
    end
  end

end
