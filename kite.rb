require 'rack'

class Kite

  attr_accessor :req, :res

  def initialize(&block)
    @maps = []
    @default = { :block => Proc.new{} }
    self.instance_eval(&block)
  end

  def call(env)
    @req = Rack::Request.new(env)
    @res = Rack::Response.new

    catch(:halt) do
      spi = split_path_info
      map = find_mapping!(spi) || @default
      map[:block_params] = [map[:request_method], *spi]
      map[:block].call(map[:block_params])
    end

    @res.finish
  end

  def on(request_method, *path_segments, &block)
    @maps << {
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
    strings.each do |s|
      @res.write s
      @res.write "\n"
    end
  end

  private
  def split_path_info
    @req.path_info == '/' ? ['/'] : @req.path_info.sub('/', '').split('/')
  end

  # The heart of a Kite application. The longest mappings are checked first,
  # because they're the most specific.
  def find_mapping!(split_path_info)
    @maps.sort_by{ |m| -m[:path_segments].length }.detect do |map|
      next if @req.request_method != map[:request_method]
      next if split_path_info.length != map[:path_segments].length
      (0...(map[:path_segments].length)).collect { |i|
        map[:path_segments][i].match(split_path_info[i]).to_a.first
      }.all?
    end
  end

end
