require "cossack"

# Method for redirections using the cossack http client
module HTTPHelper
  extend self

  def get_string(url)
    response = Cossack::Client.new(&.use Cossack::RedirectionMiddleware).get url
    case response.status
    when 200, 301, 302 then response.body
    else
      raise "status code #{response.status}: " + url
    end
  rescue ex
    raise Exception.new "failed to get #{url.colorize.underline}:\n#{ex}", ex
  end

  def get_file(url : String, path : String = File.basename(url))
    File.write path, self.get_string(url)
  end

  def url?(link) : Bool
    link.starts_with?("http://") || link.starts_with?("https://")
  end
end
