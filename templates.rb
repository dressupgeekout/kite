require 'erb'

class Kite

  def erb(template)
    begin
      body = File.read(template)
    rescue
      default!
    end
    puts ERB.new(body).result(binding)
  end

end
