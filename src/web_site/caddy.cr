require "./site"

# Limited Caddyfile parser/builder
struct WebSite::Caddy
  include Site
  @extra : IO::Memory = IO::Memory.new

  # Parses a Caddyfile from a path.
  #
  # ameba:disable Metrics/CyclomaticComplexity
  def initialize(@file : Path)
    if File.exists? @file.to_s
      line_number = 0
      header_block = false

      File.each_line @file do |raw_line|
        stripped_line = raw_line.strip "\t "

        if line_number == 0
          stripped_line.split(' ') do |host|
            @hosts << URI.parse "//" + host if host != "{"
          end
        elsif header_block
          header, _, value = stripped_line.partition " \""
          if header == "}"
            header_block = false
          else
            @headers[header] = value.rchop '"'
          end
          next
        else
          directive, _, value = stripped_line.partition ' '
          case directive
          when "root"    then @root = Path[value]
          when "log"     then @log_file_output = Path[value]
          when "errors"  then @log_file_error = Path[value]
          when "proxy"   then @proxy = URI.parse "//" + value.partition(' ')[2]
          when "fastcgi" then @fastcgi = URI.parse value.partition(' ')[2].rchop " php"
          when "gzip"    then @gzip = true
          when "header"  then header_block = true
          else
            @extra << '\n' if !@extra.empty?
            @extra << raw_line
          end
        end
        line_number += 1
      rescue ex
        raise Exception.new "Caddyfile parsing error at line #{line_number} for #{raw_line}", ex
      end
    end
  end

  # Writes to the Caddyfile path.
  def write
    File.open @file.to_s, "w" do |io|
      @hosts.try &.each do |host|
        io << host.to_s.lchop("//") << ' '
      end
      io << '{'
      io << "\n    root " << @root if @root
      if proxy = @proxy
        io << "\n    proxy / " << proxy.to_s.lchop("//")
      end
      io << "\n    fastcgi / " << @fastcgi << " php" if @fastcgi
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
