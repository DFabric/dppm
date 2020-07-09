require "colorize"
require "http"

REDIRECT_THRESH = {% if threshold = flag? :redirect_threshold %}
                    {{ threshold }}
                  {% else %}
                    10
                  {% end %}

# Method for redirections using the stdlib http client
module DPPM::HTTPHelper
  extend self

  def get_string(url, headers = nil, redirection = 0)
    raise "Probable redirection loop" if redirection > REDIRECT_THRESH
    response = HTTP::Client.get url, headers

    case response.status
    when .success? then response.body? || response.body_io.gets_to_end
    when .redirection?
      get_string url: response.headers["Location"],
        headers: headers,
        redirection: redirection + 1
    else raise %<Server returned "#{response.status}" status>
    end
  rescue ex
    raise Error.new "Failed to get #{url.colorize.underline}", cause: ex
  end

  def get_file(url : String, path : String = File.basename(url))
    File.write path, self.get_string(url)
  end

  def url?(link) : Bool
    link.starts_with?("http://") || link.starts_with?("https://")
  end
end
