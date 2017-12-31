require "cossack"

# Method for redirections using the cossack http client
module HTTPGet
  extend self

  def string(url)
    begin
      response = Cossack::Client.new do |client|
        client.use Cossack::RedirectionMiddleware, limit: 8
        client.request_options.connect_timeout = 4.seconds
      end.get url

      case response.status
      when 200, 301, 302 then response.body
      else
        raise "status code #{response.status}: " + response.body
      end
    rescue ex
      raise "can't get `#{url}`: #{ex}"
    end
  end

  def file(url, path = File.basename(url))
    File.write path, HTTPGet.string(url)
  end
end
