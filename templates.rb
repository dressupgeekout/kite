require 'erb'

class Kite

  def erb(template)
    body = try_to_read(template)
    puts ERB.new(body).result(binding)
  end

  def render(template, layout='views/layout.erb', layout_splitter='[[ YIELD ]]')
    split_layout = File.read(layout).split(layout_splitter)
    body = try_to_read(template)
    puts ERB.new(split_layout.first + body + split_layout.last).result(binding)
  end

  private

  def try_to_read(template)
    begin
      body = File.read(template)
    rescue
      default!
    end
    body
  end

end
