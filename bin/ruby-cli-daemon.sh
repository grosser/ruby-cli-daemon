#!/usr/bin/env sh
set -e # add "x" here to debug

# except for development we run from a symlink, make development and `gem open` easy
# NOTE: cannot use realpath since that is only available when coreutils is installed
real=$(readlink $0) || real=$0
lib=$(dirname $real)/../lib

case "$1" in
stop)
  # Not ruby-cli-daemon, so it does not kill my current editor in that folder
  exec pkill -f ruby_cli_daemon
  ;;
-v|--version)
  exec ruby -r$lib/ruby_cli_daemon/version.rb -e "puts RubyCliDaemon::VERSION"
  ;;
""|-*)
  echo "Usage:"
  echo "  ruby-cli-daemon <gem-executable> [arg]*"
  echo "    Start or use background worker to execute command"
  echo "    For example: ruby-cli-daemon rake --version"
  echo ""
  echo "  ruby-cli-daemon stop"
  echo "    Kill all spawned processes"
  echo ""
  echo "Options:"
  echo "  -v / --version     Show version"
  echo "  -h / --help        Show this help"
  if [[ "$1" = "-h" || "$1" = "--help" ]]; then
    exit 0
  else
    exit 1
  fi
  ;;
esac

executable=$1
shift

# matching the `stop` pattern so everything can be killed quickly
socket=${TMPDIR}ruby_cli_daemon/$(pwd | md5 | cut -c1-7)/${executable}
log=${TMPDIR}ruby_cli_daemon.log

# spawn new daemon if none exists
if [[ ! -e $socket ]]; then
  # absolute executable so a single gem install is enough for all rubies
  nohup ruby -r$lib/ruby_cli_daemon.rb -e RubyCliDaemon.start\ \"$socket\",\ \"$executable\" 0<&- &>$log &
  while [ ! -e $socket ]; do
    sleep 0.1
    kill -0 $(jobs -p) &>/dev/null || (cat $log && rm -f $log && false) # fail fast when worker failed
  done
fi

# clear previous exit and pid
status="${socket}.status"
pid="${socket}.pid"
rm -f $status $pid

# send IOs / command / env ... TODO: use perl or awk or bash to be faster ... see experiments/send_io.sh
ruby --disable-gems -rsocket -rshellwords -e "
  s = UNIXSocket.new('$socket')
  s.send_io STDOUT
  s.send_io STDERR
  s.send_io STDIN
  s.puts ARGV.shelljoin # as a single line <-> gets
  s.print ENV.map { |k, v| %(#{k} #{v}) }.join('--RCD--')
" -- "$@"

# pass HUP INT QUIT PIPE TERM to the child process
# - substract 128 which bash adds
# - we cannot send 2, so we send 15 instead which is pretty close
trap 'ex=$(expr $? - 128); if [[ "$ex" = "2" ]]; then ex=15; fi; echo $ex; kill -$ex $(cat $pid)' 1 2 3 13 15

# wait for command to finish, tight loop so we don't lose time TODO: open another socket to be faster/efficient?
while [ ! -f $status ]; do sleep 0.02; done

# replay exit status
exit "$(cat $status)"
