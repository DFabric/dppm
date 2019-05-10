require "uri"

module WebSite::Site
  property root : Path? = nil,
    log_file_output : Path? = nil,
    log_file_error : Path? = nil,
    headers : Hash(String, String) = Hash(String, String).new,
    gzip : Bool = false,
    fastcgi : String? = nil,
    proxy : URI? = nil,
    hosts : Array(URI) = Array(URI).new,
    file : Path
end
