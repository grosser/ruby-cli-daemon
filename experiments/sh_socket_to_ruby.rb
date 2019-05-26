# frozen_string_literal: true
#
# how do unix sockets work ... and are they fast enough ?
require "bundler/setup"
require "socket"
require "benchmark"

path = "/tmp/socket-experiments"
File.unlink path if File.exist?(path)

# start this first
server = UNIXServer.new(path)

puts(Benchmark.realtime do
  # write to it
  t = Thread.new { `printf "hello" | nc -U #{path}` }

  # read it
  if IO.select([server])
    conn = server.accept
    puts "GOT #{conn.gets}"
    conn.close
  end

  t.join # TODO: never finishes ... even with a fork, but works when done from a different shell
end)
