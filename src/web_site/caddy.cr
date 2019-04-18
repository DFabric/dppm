require "./site"

# Limited Caddy parser
struct WebSite::Caddy
  include Site
  @extra : IO::Memory = IO::Memory.new

  def initialize(@file : String)
    if File.exists? @file
      line_number = 0
      header_block = false

      File.each_line @file do |raw_line|
        if line_number == 0
          line = raw_line.strip("\t ").rchop(" {").split ' '
          line.each do |host|
            @hosts << URI.parse "//" + host
          end
        elsif header_block
          line = raw_line.strip("\t ").split " \"", limit: 2
          if line.first == "}"
            header_block = false
          else
            @headers[line.first] = line[1].rchop '"'
          end
          next
        else
          line = raw_line.strip("\t ").split ' '
          case line.shift
          when "root"    then @root = line[0]
          when "log"     then @log_file_output = line[0]
          when "errors"  then @log_file_error = line[0]
          when "proxy"   then @proxy = URI.parse "//" + line[1]
          when "fastcgi" then @fastcgi = line[1].lchop "unix:"
          when "gzip"    then @gzip = true
          when "header"  then header_block = true
          else
            @extra << '\n' if !@extra.empty?
            @extra << raw_line
          end
        end
        line_number += 1
      rescue ex
        raise Exception.new "Caddyfile parsing error at line #{line_number} for #{raw_line}:\n#{ex}", ex
      end
    end
  end

  def write
    File.open @file, "w" do |io|
      @hosts.try &.each do |host|
        io << host.to_s.lchop("//") << ' '
      end
      io << "{"
      io << "\n    root " << @root if @root
      if proxy = @proxy
        io << "\n    proxy / " << proxy.to_s.lchop("//")
      end
      io << "\n    fastcgi / unix:" << @fastcgi << " php" if @fastcgi
      io << "\n    log " << @log_file_output
      io << "\n    errors " << @log_file_error
      io << "\n    gzip" if @gzip
      if !@headers.empty?
        io << "\n\n    header / {"
        @headers.each do |header, value|
          io << "\n        " << header << " \"" << value << '"'
        end
        io << "\n    }\n"
      end
      if @extra.empty?
        io << "}\n"
      else
        io << '\n' << @extra
      end
    end
  end
end
