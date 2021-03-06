# frozen_string_literal: true
name = "ruby-cli-daemon"
$LOAD_PATH << File.expand_path("lib", __dir__)
require "ruby_cli_daemon/version"

Gem::Specification.new name, RubyCliDaemon::VERSION do |s|
  s.summary = "Preforking daemon that makes all ruby binaries faster"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = `git ls-files lib/ bin/ MIT-LICENSE`.split("\n")
  s.license = "MIT"
  s.required_ruby_version = ">= 2.3.0"
  s.post_install_message = %(To finish the update, run:\nruby -rruby_cli_daemon -e "RubyCliDaemon.install '/usr/local/bin/ruby-cli-daemon'\nruby-cli-daemon stop\n")
end
