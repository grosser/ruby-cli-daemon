# frozen_string_literal: true
#
# can we capture all out of a command ?
require "bundler/setup"
require "tempfile"

def capture(stream, path)
  const = Object.const_get(stream)
  old_stream = const.dup
  const.flush # not sure if that's necessary
  const.reopen(path)
  yield
ensure
  const&.flush # not sure if that's necessary
  const&.reopen(old_stream)
end

Tempfile.open do |f|
  capture :STDOUT, f.path do
    system "echo 1"
  end
  f.rewind
  puts "FILE #{f.read}"
end
