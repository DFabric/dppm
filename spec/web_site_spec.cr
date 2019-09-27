require "./spec_helper"
require "../src/web_site"

TEST_CADDYFILE = <<-E
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

def test_create_caddy_file(&block)
  tempfile = spec_temp_prefix + "-temp_caddy_site"
  File.write tempfile, TEST_CADDYFILE
  caddy_site = WebSite::Caddy.new Path[tempfile]
  begin
    yield caddy_site
  ensure
    File.delete caddy_site.file
  end
end

describe WebSite do
  test_create_caddy_file do |caddy_site|
    it "parses root" do
      caddy_site.root.should eq Path["root_site"]
    end

    it "parses log_file_output" do
      caddy_site.log_file_output.should eq Path["/output"]
    end

    it "parses log_file_error" do
      caddy_site.log_file_error.should eq Path["/error"]
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
      caddy_site.fastcgi.should eq URI.new scheme: "unix", path: "/php-fpm.sock"
    end

    it "parses headers" do
      caddy_site.headers.should eq({"X-Frame-Options" => "DENY", "Content-Security-Policy" => "frame-ancestors 'none';"})
    end

    it "builds to a Caddyfile" do
      caddy_site.write
      begin
        File.read(caddy_site.file).should eq TEST_CADDYFILE
      ensure
        File.delete caddy_site.file
      end
    end
  end
end
