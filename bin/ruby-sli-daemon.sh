#!/usr/bin/env sh
set -e # add "x" to debug

lib=$(dirname $(realpath $0))/../lib

case "$1" in
stop)
  # Not ruby-cli-daemon, so it does not kill my current editor in that folder
  exec pkill -f ruby_cli_daemon
  ;;
-v|--version)
  exec ruby -r$lib/ruby_cli_daemon/version.rb -e "puts RubyCliDaemon::VERSION"
  ;;
-h|--help)
  echo "Usage:"
  echo "  ruby-cli-daemon <ruby-executable> [arg]*"
  echo "    Start or use background worker to execute command"
  echo "    For example: ruby-cli-daemon rake --version"
  echo ""
  echo "  ruby-cli-daemon stop"
  echo "    Kill all spawned processes"
  echo ""
  echo "Options:"
  echo "  -v / --version     Show version"
  echo "  -h / --help        Show this help"
  exit
  ;;
esac

executable=$1
shift

# matching the `stop` pattern so everything can be killed quickly
socket=${TMPDIR}ruby_cli_daemon/$(basename $PWD)/${executable}
log=${TMPDIR}ruby_cli_daemon.log

# spawn new daemon if none exists
if [[ ! -e $socket ]]; then
  # absolute executable so a single gem install is enough for all rubies
  nohup ruby -r$lib/ruby_cli_daemon.rb -rbundler/setup -e RubyCliDaemon.start\ \"$socket\",\ \"$executable\" 0<&- &>$log &
  while [ ! -e $socket ]; do
    sleep 0.1
    kill -0 $(jobs -p) || (echo "Failed to start worker, check $log" && false) # fail fast when worker failed
  done
fi

# prepare output so we can start tailing
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

# wait for command to finish, tight loop so we don't lose time
while [ ! -f $status ]; do sleep 0.02; done

# kill log streamers, they should be done (but not the spawned worker)
for job in `jobs -p | tail -n2`; do kill $job; done

# replay exit status
exit "$(cat $status)"
