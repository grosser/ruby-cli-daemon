#!/usr/bin/env bash

# send an IO via a socket and use it from ruby

set -ex

socket=/tmp/socket-experiments
log=/tmp/socket-experiments-log
rm -f $socket $log

# just read
# ruby -rsocket -e "p UNIXServer.new('$socket').accept.gets" &

# via FD ... works with & but not with nohup
# nohup ruby -rsocket -e "IO.for_fd(Integer(UNIXServer.new('$socket').accept.gets)).puts 222" &

# via recv_io ... gets \x00 when using via send_io but sending that via printf did not work
nohup ruby -rsocket -e "UNIXServer.new('$socket').accept.recv_io.puts 222" 0<&- &>$log &

sleep 1 # let it boot

# send with ruby ... sadly 0.12s slow :(
time ruby --disable-gems -rsocket -e "UNIXSocket.new('$socket').send_io STDOUT;exit!"

# send with perl ... 0.02s
# time perl -e 'use IO::Socket::UNIX; $socket = IO::Socket::UNIX->new(Type => SOCK_STREAM(), Peer => "/tmp/socket-experiments"); $socket->send_io(STDOUT)'

# send with sh (0/1/2)
# echo "1" | nc -U $socket

sleep 1

cat $log
for job in `jobs -p | tail -n2`; do kill $job; done
