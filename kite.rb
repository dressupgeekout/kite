require 'rack'
require 'set'

class Kite

  attr_reader :req, :res

  def initialize(&block)
    @routes = Set.new
    @default = { :block => Proc.new{} }
    self.instance_eval(&block)
  end

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

  def on(request_method, *path_segments, &block)
    @routes << {
      :request_method => request_method,
      :path_segments  => path_segments,
      :block_params   => [request_method, *path_segments],
      :block          => block
    }
  end

  def get; 'GET'; end
  def post; 'POST'; end
  def put; 'PUT'; end
  def delete; 'DELETE'; end

  # The setter for the default response.
  def default(&block)
    @default = { :block => block }
  end

  # Force the application to stop whatever it's doing and respond the default
  # response.
  def default!
    @default[:block].call
    throw(:halt)
  end

  def segment
    /\A([\w-]+)\z/
  end

  def number
    /\A(\d+)\z/
  end

  def params(*args)
    if block_given?
      args.collect! { |a| @req.params[a] }
      yield *args
    else
      @req.params
    end
  end

  def params?
    @req.params.any?
  end

  def print(*strings)
    strings.each { |s| @res.write s }
  end

  def puts(*strings)
    strings.each { |s| @res.write "#{s}\n" }
  end

  private
  def split_path_info!
    @spi = if (@req.path_info == '/')
             ['/']
           else
             @req.path_info.sub('/', '').split('/')
           end
  end

  # The heart of a Kite application. The longest mappings are checked first,
  # because they're the most specific.
  def find_route!
    @routes.sort_by{ |r| -r[:path_segments].length }.detect do |route|
      next if @req.request_method != route[:request_method]
      next if @spi.length != route[:path_segments].length
      (0...(route[:path_segments].length)).collect { |i|
        route[:path_segments][i].match(@spi[i]).to_a.first
      }.all?
    end
  end

end
