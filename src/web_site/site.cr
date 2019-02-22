require "uri"

module WebSite::Site
  property root : String? = nil,
    log_file_output : String? = nil,
    log_file_error : String? = nil,
    headers : Hash(String, String) = Hash(String, String).new,
    gzip : Bool = false,
    fastcgi : String? = nil,
    proxy : URI? = nil,
    hosts : Array(URI) = Array(URI).new,
    file : String
end
