require "./spec_helper"
require "../src/web_site"

CADDY_SITE_FILE = __DIR__ + "/temp_caddy_site"

describe WebSite do
  caddyfile = <<-E
  example.com {
      root root_site
      proxy / [::1]:8000
      fastcgi / unix:/php-fpm.sock php
      log /output
      errors /error
      gzip

      header / {
          X-Frame-Options "DENY"
          Content-Security-Policy "frame-ancestors 'none';"
      }

      redir /.well-known /remote.php 301

      rewrite {
          r /uploads\/(.*)\.php
          to /
      }

      rewrite {
          if {path} not_match ^\/admin
          to {path} {path}/ /index.php?{query}
      }

      status 403 {
          /data
          /config
          /README
      }
  }
  E
  File.write CADDY_SITE_FILE, caddyfile
  caddy_site = WebSite::Caddy.new CADDY_SITE_FILE

  it "parses root" do
    caddy_site.root.should eq "root_site"
  end

  it "parses log_file_output" do
    caddy_site.log_file_output.should eq "/output"
  end

  it "parses log_file_error" do
    caddy_site.log_file_error.should eq "/error"
  end

  it "parses gzip" do
    caddy_site.gzip.should be_true
  end

  it "parses hosts" do
    caddy_site.hosts.should eq [URI.parse "//example.com"]
  end

  it "parses proxy" do
    caddy_site.proxy.should eq URI.parse("//[::1]:8000")
  end

  it "parses fastcgi" do
    caddy_site.fastcgi.should eq "/php-fpm.sock"
  end

  it "parses headers" do
    caddy_site.headers.should eq({"X-Frame-Options" => "DENY", "Content-Security-Policy" => "frame-ancestors 'none';"})
  end

  it "builds to a Caddyfile" do
    caddy_site.write
    File.read(CADDY_SITE_FILE).should eq caddyfile
  end
ensure
  File.delete(CADDY_SITE_FILE) if File.exists? CADDY_SITE_FILE
end
