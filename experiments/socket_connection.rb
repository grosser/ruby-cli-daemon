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
  socket = UNIXSocket.new(path)
  socket.puts("HELLO")

  # read it
  if IO.select([server])
    puts server.accept.gets
  end
end)
