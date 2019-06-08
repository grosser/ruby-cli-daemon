#!/usr/bin/env bash

# send an IO via a socket and use it from ruby

set -ex

socket=/tmp/socket-experiments
rm -f $socket

# use ... recv_io did not work, gets \x00 when using via send_io but sending that via printf did not work
ruby -rsocket -e "IO.for_fd(Integer(UNIXServer.new('$socket').accept.gets)).puts 1" &

sleep 1 # let it boot

# send with ruby
# ruby -rsocket -e "UNIXSocket.new('$socket').send_io STDOUT"

# send with sh (0/1/2)
echo "1" | nc -U $socket
