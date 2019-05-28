#!/usr/bin/env sh
set -e # add "x" to debug

executable=$1
shift
socket=${TMPDIR}ruby-cli-daemon/$(basename $PWD)/${executable}

# spawn new daemon if none exists
if [[ ! -e $socket ]]; then
  # absolute executable so a single gem install is enough for all rubies
  nohup ruby -r$(dirname $(realpath $0))/../lib/ruby_cli_daemon.rb -rbundler/setup -e RubyCliDaemon.start\ \"$socket\",\ \"$executable\" 0<&- &>/dev/null &
  while [ ! -e $socket ]; do
    sleep 0.1
    kill -0 $(jobs -p) || (echo "Failed to start worker" && false) # fail fast when worker failed
  done
fi

status="${socket}.status"
stdout="${socket}.out"
stderr="${socket}.err"
rm -f $status $stdout $stderr # clear previous
touch $stdout $stderr

# send the command to the daemon
echo $@ | nc -U $socket

# stream output
tail -f $stdout &
tail -f $stderr >&2 &

# wait for command to finish
while [ ! -f $status ]; do sleep 0.02; done

# kill log streamers, they should be done (but not the sub-command)
for job in `jobs -p | tail -n2`; do kill $job; done

# replay exit status
exit "$(cat $status)"
