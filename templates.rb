require 'erb'

class Kite

  # Write the result of ERBing a template to the Rack::Response.
  def erb(template)
    body = try_to_read(template)
    puts ERB.new(body).result(binding)
  end

  # Write the result of ERBing a template "wrapped around" a layout to the
  # Rack::Response.
  def render(template, layout='views/layout.erb', layout_splitter='[[ YIELD ]]')
    split_layout = File.read(layout).split(layout_splitter)
    body = try_to_read(template)
    puts ERB.new(split_layout.first + body + split_layout.last).result(binding)
  end

  private

  # Return the contents of a file only if it isn't a problem. Otherwise, return
  # the default response.
  def try_to_read(template)
    begin
      body = File.read(template)
    rescue
      default!
    end
    body
  end

end
